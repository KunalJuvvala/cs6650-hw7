#!/usr/bin/env bash
# Empties the queue between experiments (SQS allows one purge per 60s).
set -euo pipefail
REGION=${REGION:-us-west-2}
QURL=$(terraform -chdir="$(dirname "$0")/../terraform" output -raw sqs_queue_url)
aws sqs purge-queue --region "$REGION" --queue-url "$QURL"
echo "purged $QURL"
