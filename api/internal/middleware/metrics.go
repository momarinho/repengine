package middleware

import (
	"net/http"
	"strconv"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/adaptor"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	httpRequestsTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "http_requests_total",
		Help: "Total number of HTTP requests.",
	}, []string{"method", "path", "status"})

	httpRequestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "http_request_duration_seconds",
		Help:    "HTTP request duration in seconds.",
		Buckets: prometheus.DefBuckets,
	}, []string{"method", "path"})

	httpRequestsInFlight = promauto.NewGauge(prometheus.GaugeOpts{
		Name: "http_requests_in_flight",
		Help: "Current number of HTTP requests being processed.",
	})
)

// Metrics returns a Fiber middleware that records Prometheus metrics for every
// request.  The /metrics endpoint itself is excluded to avoid self-referential
// noise in the counters.
func Metrics() fiber.Handler {
	return func(c *fiber.Ctx) error {
		// Skip instrumentation for the metrics scrape endpoint itself.
		if c.Path() == "/metrics" {
			return c.Next()
		}

		httpRequestsInFlight.Inc()
		defer httpRequestsInFlight.Dec()

		start := time.Now()
		err := c.Next()
		duration := time.Since(start).Seconds()

		// Use the matched route pattern (e.g. "/workflows/:id") rather than the
		// raw request path so high-cardinality values don't pollute the labels.
		path := c.Path()
		if route := c.Route(); route != nil && route.Path != "" {
			path = route.Path
		}
		method := c.Method()
		status := strconv.Itoa(c.Response().StatusCode())

		httpRequestsTotal.WithLabelValues(method, path, status).Inc()
		httpRequestDuration.WithLabelValues(method, path).Observe(duration)

		return err
	}
}

// MetricsHandler returns a Fiber handler that serves the default Prometheus
// metrics registry over HTTP, compatible with a standard /metrics scrape.
func MetricsHandler() fiber.Handler {
	h := promhttp.HandlerFor(
		prometheus.DefaultGatherer,
		promhttp.HandlerOpts{EnableOpenMetrics: true},
	)
	return adaptor.HTTPHandler(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h.ServeHTTP(w, r)
	}))
}
