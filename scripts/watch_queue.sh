#!/usr/bin/env bash
# Samples queue depth every 5s into a CSV. CloudWatch SQS metrics are only
# 1-minute resolution, so this gives you finer data for peak depth / drain time.
# Usage: ./scripts/watch_queue.sh results/queue_5workers.csv   (Ctrl-C to stop)
set -euo pipefail
REGION=${REGION:-us-west-2}
OUT=${1:-queue_depth.csv}
QURL=$(terraform -chdir="$(dirname "$0")/../terraform" output -raw sqs_queue_url)
echo "timestamp,visible,in_flight" > "$OUT"
while true; do
  read -r VIS INF < <(aws sqs get-queue-attributes --region "$REGION" --queue-url "$QURL" \
    --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
    --query 'Attributes.[ApproximateNumberOfMessages,ApproximateNumberOfMessagesNotVisible]' --output text)
  TS=$(date +%H:%M:%S)
  echo "$TS,$VIS,$INF" | tee -a "$OUT"
  sleep 5
done
