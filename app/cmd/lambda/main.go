// Lambda order processor: subscribed directly to the SNS topic.
package main

import (
	"context"
	"encoding/json"
	"log"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/kunal/hw7/internal/order"
)

func handler(ctx context.Context, evt events.SNSEvent) error {
	for _, rec := range evt.Records {
		var o order.Order
		if err := json.Unmarshal([]byte(rec.SNS.Message), &o); err != nil {
			log.Printf("bad message %s: %v", rec.SNS.MessageID, err)
			continue
		}
		start := time.Now()
		time.Sleep(order.PaymentDelay) // same 3s payment simulation
		log.Printf("processed order=%s customer=%d in %v", o.OrderID, o.CustomerID, time.Since(start))
	}
	return nil
}

func main() { lambda.Start(handler) }
