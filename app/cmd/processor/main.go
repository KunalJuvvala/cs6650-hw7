// Order Processor: long-polls SQS and processes orders with WORKER_COUNT
// concurrent goroutines (each = one payment "lane", 3s per order).
package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strconv"
	"sync/atomic"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/aws/aws-sdk-go-v2/service/sqs/types"
	"github.com/kunal/hw7/internal/order"
)

func envInt(k string, def int) int {
	if v, err := strconv.Atoi(os.Getenv(k)); err == nil && v > 0 {
		return v
	}
	return def
}

func main() {
	queueURL := os.Getenv("SQS_QUEUE_URL")
	workers := envInt("WORKER_COUNT", 1)
	if queueURL == "" {
		log.Fatal("SQS_QUEUE_URL is required")
	}
	ctx := context.Background()
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		log.Fatalf("aws config: %v", err)
	}
	client := sqs.NewFromConfig(cfg)

	// /health so the ECS container health check has something to hit.
	go func() {
		http.HandleFunc("/health", func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusOK) })
		log.Fatal(http.ListenAndServe(":8080", nil))
	}()

	var processed, inFlight atomic.Int64
	// Throughput logger: makes "processing rate" easy to read off CloudWatch Logs.
	go func() {
		var last int64
		for range time.Tick(10 * time.Second) {
			cur := processed.Load()
			log.Printf("[stats] workers=%d in_flight=%d processed_total=%d rate=%.2f orders/s",
				workers, inFlight.Load(), cur, float64(cur-last)/10.0)
			last = cur
		}
	}()

	// sem has one slot per worker goroutine. We only pull from SQS as many
	// messages as we have free workers, so no message sits in memory long
	// enough to exceed the 30s visibility timeout and get redelivered.
	sem := make(chan struct{}, workers)
	log.Printf("processor started: workers=%d queue=%s", workers, queueURL)

	for {
		sem <- struct{}{} // wait until at least one worker is free
		batch := 1 + (workers - len(sem))
		if batch > 10 {
			batch = 10
		}
		for i := 1; i < batch; i++ { // reserve the rest (never blocks: we're the only acquirer)
			sem <- struct{}{}
		}

		out, err := client.ReceiveMessage(ctx, &sqs.ReceiveMessageInput{
			QueueUrl:            aws.String(queueURL),
			MaxNumberOfMessages: int32(batch),
			WaitTimeSeconds:     20, // long polling
		})
		if err != nil {
			log.Printf("receive error: %v", err)
			for i := 0; i < batch; i++ {
				<-sem
			}
			time.Sleep(time.Second)
			continue
		}
		for i := len(out.Messages); i < batch; i++ { // give back unused slots
			<-sem
		}
		for _, m := range out.Messages {
			inFlight.Add(1)
			go func(m types.Message) {
				defer func() { <-sem; inFlight.Add(-1) }()
				var o order.Order
				if err := json.Unmarshal([]byte(aws.ToString(m.Body)), &o); err != nil {
					log.Printf("bad message %s: %v", aws.ToString(m.MessageId), err)
				}
				time.Sleep(order.PaymentDelay) // simulated payment verification
				if _, err := client.DeleteMessage(ctx, &sqs.DeleteMessageInput{
					QueueUrl:      aws.String(queueURL),
					ReceiptHandle: m.ReceiptHandle,
				}); err != nil {
					log.Printf("delete failed for %s: %v", o.OrderID, err)
					return
				}
				processed.Add(1)
			}(m)
		}
	}
}
