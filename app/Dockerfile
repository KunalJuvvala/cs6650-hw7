# Build one image per binary:  docker build --build-arg APP=receiver ...
FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
ARG APP
RUN CGO_ENABLED=0 GOOS=linux go build -o /out/app ./cmd/${APP}

FROM alpine:3.20
# busybox wget in alpine is used by the ECS container health check
COPY --from=build /out/app /app
EXPOSE 8080
ENTRYPOINT ["/app"]
