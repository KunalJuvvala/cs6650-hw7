#!/usr/bin/env bash
# Forces ECS to pull the latest image.
set -euo pipefail
REGION=${REGION:-us-west-2}
for svc in order-receiver order-processor; do
  aws ecs update-service --region "$REGION" --cluster hw7-cluster --service "$svc" --force-new-deployment >/dev/null
  echo "redeploying $svc"
done
aws ecs wait services-stable --region "$REGION" --cluster hw7-cluster --services order-receiver order-processor
echo "stable"
