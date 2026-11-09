#!/usr/bin/env bash
# Usage: ./scripts/build_and_push.sh   (run from repo root, after the ECR repos exist)
set -euo pipefail
REGION=${REGION:-us-west-2}
cd "$(dirname "$0")/.."
RECEIVER_REPO=$(terraform -chdir=terraform output -raw receiver_repo)
PROCESSOR_REPO=$(terraform -chdir=terraform output -raw processor_repo)
REGISTRY=${RECEIVER_REPO%%/*}

aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"

# --platform matters on Apple Silicon: Fargate default is x86_64
docker buildx build --platform linux/amd64 --provenance=false --build-arg APP=receiver  -t "$RECEIVER_REPO:latest"  --push app
docker buildx build --platform linux/amd64 --provenance=false --build-arg APP=processor -t "$PROCESSOR_REPO:latest" --push app
echo "Pushed. If services already exist, run ./scripts/redeploy.sh"
