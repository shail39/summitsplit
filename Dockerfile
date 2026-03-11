# ---- Build Stage ----
FROM golang:1.25-bookworm AS builder

WORKDIR /app

# Copy dependency files first for better layer caching
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# lib/pq is pure Go — no CGO needed
RUN CGO_ENABLED=0 GOOS=linux go build -o bin/summitsplit ./cmd/server

# ---- Run Stage ----
FROM gcr.io/distroless/static-debian12

WORKDIR /app

# Copy binary and web assets from builder
COPY --from=builder /app/bin/summitsplit ./summitsplit
COPY --from=builder /app/web ./web

ENV PORT=8080

EXPOSE 8080

CMD ["./summitsplit"]
