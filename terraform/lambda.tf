# ---------------- Part III: Lambda ----------------
# Build first:  (cd ../app && GOOS=linux GOARCH=amd64 CGO_ENABLED=0 \
#                 go build -tags lambda.norpc -o ../build/lambda/bootstrap ./cmd/lambda)

data "archive_file" "lambda" {
  count       = var.deploy_lambda ? 1 : 0
  type        = "zip"
  source_file = "${path.module}/../build/lambda/bootstrap"
  output_path = "${path.module}/../build/lambda.zip"
}

resource "aws_iam_role" "lambda" {
  count = var.deploy_lambda && !local.use_lab ? 1 : 0
  name  = "${var.project}-lambda"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  count      = var.deploy_lambda && !local.use_lab ? 1 : 0
  role       = aws_iam_role.lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "processor" {
  count            = var.deploy_lambda ? 1 : 0
  function_name    = "${var.project}-order-processor"
  role             = local.use_lab ? data.aws_iam_role.lab[0].arn : aws_iam_role.lambda[0].arn
  filename         = data.archive_file.lambda[0].output_path
  source_code_hash = data.archive_file.lambda[0].output_base64sha256
  handler          = "bootstrap"
  runtime          = "provided.al2" # if AWS rejects this runtime, use "provided.al2023" and note it in the report
  architectures    = ["x86_64"]
  memory_size      = 512
  timeout          = 10
}

resource "aws_lambda_permission" "sns" {
  count         = var.deploy_lambda ? 1 : 0
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.orders.arn
}

# Toggle instead of commenting out: -var enable_lambda_subscription=false before ANY Locust run
resource "aws_sns_topic_subscription" "lambda" {
  count      = var.deploy_lambda && var.enable_lambda_subscription ? 1 : 0
  topic_arn  = aws_sns_topic.orders.arn
  protocol   = "lambda"
  endpoint   = aws_lambda_function.processor[0].arn
  depends_on = [aws_lambda_permission.sns]
}
