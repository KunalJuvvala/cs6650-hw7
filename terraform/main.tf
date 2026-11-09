terraform {
  required_version = ">= 1.5"
  required_providers {
    aws     = { source = "hashicorp/aws", version = "~> 5.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.4" }
  }
}

provider "aws" {
  region = var.region
}

locals {
  use_lab = var.lab_role_name != ""
}

# ---------------- Messaging ----------------
resource "aws_sns_topic" "orders" {
  name = "order-processing-events"
}

resource "aws_sqs_queue" "orders" {
  name                       = "order-processing-queue"
  visibility_timeout_seconds = 30     # default
  message_retention_seconds  = 345600 # 4 days (default)
  receive_wait_time_seconds  = 20     # long polling
}

resource "aws_sqs_queue_policy" "allow_sns" {
  queue_url = aws_sqs_queue.orders.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.orders.arn
      Condition = { ArnEquals = { "aws:SourceArn" = aws_sns_topic.orders.arn } }
    }]
  })
}

# raw_message_delivery = SQS body is just our Order JSON (no SNS envelope)
resource "aws_sns_topic_subscription" "sqs" {
  topic_arn            = aws_sns_topic.orders.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.orders.arn
  raw_message_delivery = true
}

# ---------------- ECR ----------------
resource "aws_ecr_repository" "receiver" {
  name         = "${var.project}-receiver"
  force_delete = true
}

resource "aws_ecr_repository" "processor" {
  name         = "${var.project}-processor"
  force_delete = true
}

# ---------------- IAM ----------------
data "aws_iam_role" "lab" {
  count = local.use_lab ? 1 : 0
  name  = var.lab_role_name
}

resource "aws_iam_role" "exec" {
  count = local.use_lab ? 0 : 1
  name  = "${var.project}-ecs-exec"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "exec" {
  count      = local.use_lab ? 0 : 1
  role       = aws_iam_role.exec[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  count = local.use_lab ? 0 : 1
  name  = "${var.project}-ecs-task"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy" "task" {
  count = local.use_lab ? 0 : 1
  role  = aws_iam_role.task[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["sns:Publish"], Resource = aws_sns_topic.orders.arn },
      { Effect = "Allow", Action = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ChangeMessageVisibility"], Resource = aws_sqs_queue.orders.arn }
    ]
  })
}

locals {
  exec_role_arn = local.use_lab ? data.aws_iam_role.lab[0].arn : aws_iam_role.exec[0].arn
  task_role_arn = local.use_lab ? data.aws_iam_role.lab[0].arn : aws_iam_role.task[0].arn
}

# ---------------- ECS ----------------
resource "aws_ecs_cluster" "main" {
  name = "${var.project}-cluster"
}

resource "aws_cloudwatch_log_group" "receiver" {
  name              = "/ecs/${var.project}-receiver"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "processor" {
  name              = "/ecs/${var.project}-processor"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "receiver" {
  family                   = "${var.project}-receiver"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = local.exec_role_arn
  task_role_arn            = local.task_role_arn
  container_definitions = jsonencode([{
    name         = "receiver"
    image        = "${aws_ecr_repository.receiver.repository_url}:${var.image_tag}"
    essential    = true
    portMappings = [{ containerPort = 8080, protocol = "tcp" }]
    environment = [
      { name = "SNS_TOPIC_ARN", value = aws_sns_topic.orders.arn },
      { name = "AWS_REGION", value = var.region }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.receiver.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "receiver"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "processor" {
  family                   = "${var.project}-processor"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = local.exec_role_arn
  task_role_arn            = local.task_role_arn
  container_definitions = jsonencode([{
    name      = "processor"
    image     = "${aws_ecr_repository.processor.repository_url}:${var.image_tag}"
    essential = true
    environment = [
      { name = "SQS_QUEUE_URL", value = aws_sqs_queue.orders.url },
      { name = "WORKER_COUNT", value = tostring(var.worker_count) },
      { name = "AWS_REGION", value = var.region }
    ]
    healthCheck = {
      command     = ["CMD-SHELL", "wget -qO- http://localhost:8080/health || exit 1"]
      interval    = 15
      timeout     = 5
      retries     = 3
      startPeriod = 10
    }
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.processor.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "processor"
      }
    }
  }])
}

resource "aws_ecs_service" "receiver" {
  name            = "order-receiver"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.receiver.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.receiver.arn
    container_name   = "receiver"
    container_port   = 8080
  }
  depends_on = [aws_lb_listener.http]
}

resource "aws_ecs_service" "processor" {
  name            = "order-processor"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.processor.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }
}
