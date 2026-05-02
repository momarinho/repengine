package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"os"
	"sort"
	"strconv"
	"time"
)

type workflowBlock struct {
	NodeTypeSlug string         `json:"node_type_slug"`
	Data         map[string]any `json:"data,omitempty"`
}

type workflow struct {
	ID          int             `json:"id"`
	Name        string          `json:"name"`
	Description string          `json:"description"`
	IsPublic    bool            `json:"is_public"`
	UpdatedAt   string          `json:"updated_at"`
	Blocks      []workflowBlock `json:"blocks"`
}

type apiError struct {
	Error   string `json:"error"`
	Message string `json:"message"`
}

type stats struct {
	AvgMS float64
	P50MS float64
	P95MS float64
	MaxMS float64
}

func main() {
	apiURL := getEnv("API_URL", "http://localhost:8080")
	token := os.Getenv("BENCH_TOKEN")
	if token == "" {
		fmt.Fprintln(os.Stderr, "BENCH_TOKEN is required")
		os.Exit(1)
	}

	runs := getEnvInt("BENCH_RUNS", 80)
	warmup := getEnvInt("BENCH_WARMUP", 5)

	client := &http.Client{
		Timeout: 5 * time.Second,
	}

	created, err := createWorkflow(client, apiURL, token)
	if err != nil {
		fmt.Fprintf(os.Stderr, "create workflow failed: %v\n", err)
		os.Exit(1)
	}

	defer func() {
		if err := deleteWorkflow(client, apiURL, token, created.ID); err != nil {
			fmt.Fprintf(os.Stderr, "warning: delete benchmark workflow failed: %v\n", err)
		}
	}()

	current := created

	for i := range warmup {
		current, _, err = updateWorkflow(client, apiURL, token, current, i)
		if err != nil {
			fmt.Fprintf(os.Stderr, "warmup failed at iteration %d: %v\n", i+1, err)
			os.Exit(1)
		}
	}

	durations := make([]float64, 0, runs)
	failures := 0

	for i := range runs {
		var d time.Duration
		current, d, err = updateWorkflow(client, apiURL, token, current, warmup+i)
		if err != nil {
			failures++
			fmt.Fprintf(os.Stderr, "measured run failed at iteration %d: %v\n", i+1, err)
			continue
		}
		durations = append(durations, float64(d.Microseconds())/1000.0)
	}

	if len(durations) == 0 {
		fmt.Fprintln(os.Stderr, "no successful benchmark samples collected")
		os.Exit(1)
	}

	s := computeStats(durations)

	fmt.Printf("runs=%d warmup=%d failures=%d\n", runs, warmup, failures)
	fmt.Printf("avg=%.2fms p50=%.2fms p95=%.2fms max=%.2fms\n", s.AvgMS, s.P50MS, s.P95MS, s.MaxMS)

	if failures > 0 {
		fmt.Println("FAIL: benchmark had request failures")
		os.Exit(3)
	}

	if s.P95MS < 200 {
		fmt.Println("PASS: p95 is under 200ms")
		return
	}

	fmt.Println("FAIL: p95 is 200ms or higher")
	os.Exit(2)
}

func createWorkflow(client *http.Client, apiURL, token string) (workflow, error) {
	payload := workflow{
		Name:        "Benchmark PUT Workflow",
		Description: "created by benchmark",
		IsPublic:    false,
		Blocks:      buildBlocks(0),
	}

	body, status, err := doJSON(client, http.MethodPost, apiURL+"/workflows", token, payload)
	if err != nil {
		return workflow{}, err
	}
	if status != http.StatusCreated {
		return workflow{}, decodeAPIError("create", status, body)
	}

	var out workflow
	if err := json.Unmarshal(body, &out); err != nil {
		return workflow{}, fmt.Errorf("decode create response: %w", err)
	}

	return out, nil
}

func updateWorkflow(client *http.Client, apiURL, token string, current workflow, iteration int) (workflow, time.Duration, error) {
	payload := map[string]any{
		"name":        fmt.Sprintf("Benchmark PUT Workflow %03d", iteration),
		"description": fmt.Sprintf("benchmark iteration %03d", iteration),
		"is_public":   false,
		"updated_at":  current.UpdatedAt,
		"blocks":      buildBlocks(iteration),
	}

	start := time.Now()
	body, status, err := doJSON(client, http.MethodPut, fmt.Sprintf("%s/workflows/%d", apiURL, current.ID), token, payload)
	elapsed := time.Since(start)
	if err != nil {
		return workflow{}, elapsed, err
	}
	if status != http.StatusOK {
		return workflow{}, elapsed, decodeAPIError("update", status, body)
	}

	var out workflow
	if err := json.Unmarshal(body, &out); err != nil {
		return workflow{}, elapsed, fmt.Errorf("decode update response: %w", err)
	}

	return out, elapsed, nil
}

func deleteWorkflow(client *http.Client, apiURL, token string, workflowID int) error {
	body, status, err := doJSON(client, http.MethodDelete, fmt.Sprintf("%s/workflows/%d", apiURL, workflowID), token, nil)
	if err != nil {
		return err
	}
	if status != http.StatusNoContent {
		return decodeAPIError("delete", status, body)
	}
	return nil
}

func buildBlocks(iteration int) []workflowBlock {
	blocks := []workflowBlock{
		{NodeTypeSlug: "section"},
	}

	for i := range 10 {
		blocks = append(blocks, workflowBlock{
			NodeTypeSlug: "rest",
			Data: map[string]any{
				"duration": 30 + ((iteration + i) % 6 * 5),
			},
		})
	}

	blocks = append(blocks, workflowBlock{NodeTypeSlug: "section"})

	return blocks
}

func doJSON(client *http.Client, method, url, token string, payload any) ([]byte, int, error) {
	var reqBody []byte
	var err error

	if payload != nil {
		reqBody, err = json.Marshal(payload)
		if err != nil {
			return nil, 0, fmt.Errorf("marshal request: %w", err)
		}
	}

	req, err := http.NewRequest(method, url, bytes.NewReader(reqBody))
	if err != nil {
		return nil, 0, fmt.Errorf("build request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return nil, 0, fmt.Errorf("http request: %w", err)
	}
	defer resp.Body.Close()

	body := new(bytes.Buffer)
	if _, err := body.ReadFrom(resp.Body); err != nil {
		return nil, 0, fmt.Errorf("read response: %w", err)
	}

	return body.Bytes(), resp.StatusCode, nil
}

func decodeAPIError(operation string, status int, body []byte) error {
	if len(body) == 0 {
		return fmt.Errorf("%s failed with status %d", operation, status)
	}

	var apiErr apiError
	if err := json.Unmarshal(body, &apiErr); err == nil && (apiErr.Message != "" || apiErr.Error != "") {
		msg := apiErr.Message
		if msg == "" {
			msg = apiErr.Error
		}
		return fmt.Errorf("%s failed with status %d: %s", operation, status, msg)
	}

	return fmt.Errorf("%s failed with status %d: %s", operation, status, string(body))
}

func computeStats(samples []float64) stats {
	sorted := append([]float64(nil), samples...)
	sort.Float64s(sorted)

	var sum float64
	for _, v := range sorted {
		sum += v
	}

	return stats{
		AvgMS: sum / float64(len(sorted)),
		P50MS: percentile(sorted, 0.50),
		P95MS: percentile(sorted, 0.95),
		MaxMS: sorted[len(sorted)-1],
	}
}

func percentile(sorted []float64, p float64) float64 {
	if len(sorted) == 0 {
		return 0
	}

	index := max(int(math.Ceil(p*float64(len(sorted))))-1, 0)
	if index >= len(sorted) {
		index = len(sorted) - 1
	}

	return sorted[index]
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		n, err := strconv.Atoi(v)
		if err == nil && n > 0 {
			return n
		}
	}
	return fallback
}
