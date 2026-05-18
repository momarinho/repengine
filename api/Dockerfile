# ============================================================
# Stage 1 — Builder
# ============================================================
FROM golang:1.25-alpine AS builder

ARG APP_VERSION=dev
ARG BUILD_TIME

WORKDIR /app

# Download dependencies first (layer-cache friendly)
COPY go.mod go.sum ./
RUN go mod download

# Build the binary with version metadata baked in via ldflags
COPY . .
RUN CGO_ENABLED=0 go build \
    -ldflags "-s -w -X main.version=${APP_VERSION} -X main.buildTime=${BUILD_TIME}" \
    -o server ./cmd/server

# ============================================================
# Stage 2 — Final (minimal runtime image)
# ============================================================
FROM alpine:3.19

ARG APP_VERSION=dev
ARG BUILD_TIME

# OCI image labels
LABEL org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.created="${BUILD_TIME}" \
      org.opencontainers.image.source="https://github.com/momarinho/repengine"

WORKDIR /app

# ca-certificates  — for outbound TLS calls
# wget             — used by the HEALTHCHECK probe
RUN apk add --no-cache ca-certificates wget \
    && addgroup -S appgroup \
    && adduser  -S -G appgroup appuser

# Copy the compiled binary from the builder stage
COPY --from=builder /app/server .
RUN chmod +x ./server

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -qO- http://localhost:8080/health || exit 1

# Drop root privileges before running
USER appuser

CMD ["./server"]
