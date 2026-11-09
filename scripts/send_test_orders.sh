#!/usr/bin/env bash
# Part III: send N orders via curl (NOT Locust) to exercise the Lambda.
# Usage: ./scripts/send_test_orders.sh 8
set -euo pipefail
N=${1:-5}
ALB=$(terraform -chdir="$(dirname "$0")/../terraform" output -raw alb_url)
for i in $(seq 1 "$N"); do
  curl -s -X POST "$ALB/orders/async" -H "Content-Type: application/json" \
    -d "{\"customer_id\": $((100 + i)), \"items\": [{\"product_id\": \"SKU-$i\", \"quantity\": 1, \"price\": 19.99}]}"
  echo
  sleep 1
done
