# -------- Build Stage --------
FROM golang:1.25 AS builder
WORKDIR /app

# CGO 비활성화 + 정적 빌드
ENV CGO_ENABLED=0 GOOS=linux GOARCH=arm64

COPY go.mod go.sum* ./
RUN go mod download || true

COPY . .
RUN go build -ldflags="-s -w" -o singleton .

# -------- Runtime Stage --------
# glibc 없는 경량 이미지
FROM gcr.io/distroless/static:nonroot
COPY --from=builder /app/singleton /singleton
USER nonroot:nonroot
ENTRYPOINT ["/singleton"]
