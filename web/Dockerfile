# ============================================================
# Stage 1 — Builder
# ============================================================
FROM node:20-alpine AS builder

WORKDIR /app

# Install all dependencies (dev + prod) needed to build
COPY package*.json ./
RUN npm ci

# Copy source and compile SvelteKit → adapter-node bundle
COPY . .
RUN npm run build

# Prune to production-only node_modules so the runner stage
# gets the smallest possible closure
RUN npm ci --omit=dev

# ============================================================
# Stage 2 — Runner (lean production image)
# ============================================================
FROM node:20-alpine AS runner

ENV NODE_ENV=production

WORKDIR /app

# Create a non-root user before copying any application files
RUN addgroup -S appgroup \
    && adduser  -S -G appgroup appuser

# Copy only what is needed at runtime
COPY --from=builder /app/build        ./build
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json

# Transfer ownership so appuser can read everything
RUN chown -R appuser:appgroup /app

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD wget -qO- http://localhost:3000 || exit 1

USER appuser

CMD ["node", "build"]
