# HW7 — Sync vs Async (SNS/SQS) vs Serverless (Lambda)

```
app/        Go: cmd/receiver (sync+async API), cmd/processor (SQS workers), cmd/lambda
terraform/  VPC, ALB, ECS, ECR, SNS, SQS, Lambda (toggles in variables.tf)
loadtest/   locustfile.py (SyncUser / AsyncUser)
scripts/    build/push, redeploy, queue watcher, purge, curl test orders
report/     team report template
```

Quick start (region defaults to us-west-2; export REGION to change):
```bash
cd app && go mod tidy && go build ./... && cd ..
cd terraform && terraform init
terraform apply -target=aws_ecr_repository.receiver -target=aws_ecr_repository.processor
cd .. && ./scripts/build_and_push.sh
cd terraform && terraform apply            # add -var lab_role_name=LabRole on AWS Academy
```
Scale workers: `terraform apply -var worker_count=20`
Teardown (NAT gateway + ALB cost money): `terraform destroy`
