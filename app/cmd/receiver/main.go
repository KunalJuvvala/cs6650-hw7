// Order Receiver: serves /health, POST /orders/sync and POST /orders/async.
package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sns"
	"github.com/kunal/hw7/internal/order"
)

// paymentProcessor models ONE shared payment processor. A sleeping goroutine
// doesn't block a thread, so without this every request would "pay" in
// parallel. A buffered channel of capacity 1 is a semaphore: only one payment
// can be in progress at a time => max throughput = 1 order / 3s.
var paymentProcessor = make(chan struct{}, 1)

func verifyPayment() {
	paymentProcessor <- struct{}{} // acquire (blocks while another payment runs)
	time.Sleep(order.PaymentDelay)
	<-paymentProcessor // release
}

type server struct {
	sns      *sns.Client
	topicArn string
}

func decode(w http.ResponseWriter, r *http.Request) (*order.Order, bool) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return nil, false
	}
	var o order.Order
	if err := json.NewDecoder(r.Body).Decode(&o); err != nil {
		http.Error(w, "bad json: "+err.Error(), http.StatusBadRequest)
		return nil, false
	}
	o.OrderID = order.NewID()
	o.CreatedAt = time.Now().UTC()
	return &o, true
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}

func (s *server) handleSync(w http.ResponseWriter, r *http.Request) {
	o, ok := decode(w, r)
	if !ok {
		return
	}
	o.Status = "processing"
	verifyPayment()
	o.Status = "completed"
	writeJSON(w, http.StatusOK, o)
}

func (s *server) handleAsync(w http.ResponseWriter, r *http.Request) {
	o, ok := decode(w, r)
	if !ok {
		return
	}
	o.Status = "pending"
	body, _ := json.Marshal(o)
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	if _, err := s.sns.Publish(ctx, &sns.PublishInput{
		TopicArn: aws.String(s.topicArn),
		Message:  aws.String(string(body)),
	}); err != nil {
		log.Printf("sns publish failed: %v", err)
		http.Error(w, "failed to enqueue order", http.StatusServiceUnavailable)
		return
	}
	writeJSON(w, http.StatusAccepted, o)
}

func main() {
	topicArn := os.Getenv("SNS_TOPIC_ARN")
	if topicArn == "" {
		log.Println("WARNING: SNS_TOPIC_ARN not set; /orders/async will fail")
	}
	cfg, err := config.LoadDefaultConfig(context.Background())
	if err != nil {
		log.Fatalf("aws config: %v", err)
	}
	s := &server{sns: sns.NewFromConfig(cfg), topicArn: topicArn}

	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusOK); _, _ = w.Write([]byte("ok")) })
	mux.HandleFunc("/orders/sync", s.handleSync)
	mux.HandleFunc("/orders/async", s.handleAsync)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	log.Printf("receiver listening on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, mux))
}
