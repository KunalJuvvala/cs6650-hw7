variable "region" {
  type    = string
  default = "us-west-2"
}

variable "project" {
  type    = string
  default = "hw7"
}

# Number of worker goroutines in the Order Processor (Phase 3 = 1, Phase 5 = 5/20/100...)
variable "worker_count" {
  type    = number
  default = 1
}

variable "image_tag" {
  type    = string
  default = "latest"
}

# AWS Academy / Learner Lab accounts can't create IAM roles. If that's you,
# set this to "LabRole" and every role below is replaced with the lab role.
variable "lab_role_name" {
  type    = string
  default = ""
}

# Part III: set deploy_lambda=true once ../build/lambda/bootstrap exists.
variable "deploy_lambda" {
  type    = bool
  default = false
}

# Part III: SNS -> Lambda subscription. KEEP FALSE while load testing with Locust!
variable "enable_lambda_subscription" {
  type    = bool
  default = false
}
