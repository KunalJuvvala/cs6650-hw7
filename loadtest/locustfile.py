"""
HW7 load tests. Pick the user class on the command line:

  Normal (sync):  locust -f locustfile.py SyncUser  --headless -u 5  -r 1  -t 30s --host $ALB --csv results/sync_normal
  Flash  (sync):  locust -f locustfile.py SyncUser  --headless -u 20 -r 10 -t 60s --host $ALB --csv results/sync_flash
  Flash (async):  locust -f locustfile.py AsyncUser --headless -u 20 -r 10 -t 60s --host $ALB --csv results/async_flash

NEVER run this while the SNS -> Lambda subscription is enabled.
"""
import random
from locust import HttpUser, task, between


def make_order():
    return {
        "customer_id": random.randint(1, 100_000),
        "items": [
            {
                "product_id": f"SKU-{random.randint(1, 500)}",
                "quantity": random.randint(1, 3),
                "price": round(random.uniform(5, 200), 2),
            }
            for _ in range(random.randint(1, 3))
        ],
    }


class SyncUser(HttpUser):
    wait_time = between(0.1, 0.5)

    @task
    def place_order_sync(self):
        with self.client.post("/orders/sync", json=make_order(),
                              name="POST /orders/sync", catch_response=True) as r:
            if r.status_code != 200:
                r.failure(f"status {r.status_code}")


class AsyncUser(HttpUser):
    wait_time = between(0.1, 0.5)

    @task
    def place_order_async(self):
        with self.client.post("/orders/async", json=make_order(),
                              name="POST /orders/async", catch_response=True) as r:
            if r.status_code != 202:
                r.failure(f"status {r.status_code}")
