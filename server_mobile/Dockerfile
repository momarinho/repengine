# ============================================================
# Stage 1 — Builder
# ============================================================
FROM dart:stable AS builder

WORKDIR /app

# Activate Dart Frog CLI globally
RUN dart pub global activate dart_frog_cli

# Copy shared core contract and mobile BFF dependencies
COPY packages/repengine_core ./packages/repengine_core
COPY server_mobile/pubspec.yaml server_mobile/pubspec.lock ./server_mobile/

WORKDIR /app/server_mobile
RUN dart pub get

# Copy the rest of server_mobile source code
COPY server_mobile .

# Build production bundle using dart_frog
RUN dart pub global run dart_frog_cli:dart_frog build

# Compile standalone AOT production server executable
WORKDIR /app/server_mobile/build
RUN dart pub get
RUN dart compile exe bin/server.dart -o bin/server

# ============================================================
# Stage 2 — Runtime
# ============================================================
FROM debian:bookworm-slim

# ca-certificates for TLS and curl for container health check
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -s /bin/bash appuser

WORKDIR /app

COPY --from=builder /app/server_mobile/build/bin/server /app/server
RUN chmod +x /app/server && chown appuser:appuser /app/server

USER appuser

ENV PORT=8080
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

CMD ["/app/server"]
