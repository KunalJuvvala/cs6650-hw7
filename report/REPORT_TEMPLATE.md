# HW7 Team Report — Sync vs Async vs Serverless Order Processing

Team: <name A>, <name B>, <name C>
Every section is labeled with whose results it contains. Each teammate ran every experiment independently.

## 1. Architecture (shared)
- Diagram: Client → ALB → Order Receiver (ECS) → SNS → SQS → Order Processor (ECS, N goroutines)
- Part III: SNS → Lambda (no SQS)
- Key design choices per teammate (how the 3s bottleneck was simulated, how workers pull from SQS)

## 2. Phase 1 — Synchronous baseline
| Teammate | Test | Users | Requests | Failures | Fail % | Median ms | p95 ms | RPS |
|---|---|---|---|---|---|---|---|---|
| A | Normal | 5 | | | | | | |
| A | Flash | 20 | | | | | | |
| B | ... |

What happened to customers (timeouts / 504s from the ALB, latency growing with queueing)?

## 3. Phase 2 — Bottleneck math (shared)
## 4. Phase 3 — Async acceptance (per teammate table, same columns) + "X times more orders accepted"
## 5. Phase 4 — Queue growth (CloudWatch screenshot per teammate, growth rate, backlog time)
## 6. Phase 5 — Worker scaling
| Teammate | Goroutines | Measured rate (orders/s) | Peak queue depth | Time to drain | CPU % | Mem % |
|---|---|---|---|---|---|---|

Minimum workers to keep up with 60/s: ___ (show the math and the measured confirmation)

## 7. Part III — Lambda
- Cold starts per teammate (Init Duration values, how often)
- Cost calculation for expected volume
- Switch recommendation

## 8. Cross-team comparison
Where results matched, where they differed, and why (region, Locust machine/network, ALB warm-up, worker implementation, timing of screenshots).

## 9. Mock interview answers (shared)
