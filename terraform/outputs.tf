output "alb_url" {
  value = "http://${aws_lb.main.dns_name}"
}
output "receiver_repo" {
  value = aws_ecr_repository.receiver.repository_url
}
output "processor_repo" {
  value = aws_ecr_repository.processor.repository_url
}
output "sqs_queue_url" {
  value = aws_sqs_queue.orders.url
}
output "sns_topic_arn" {
  value = aws_sns_topic.orders.arn
}
output "lambda_name" {
  value = var.deploy_lambda ? aws_lambda_function.processor[0].function_name : "not deployed"
}
