FROM golang:alpine AS build
RUN apk add --no-cache git bash make ca-certificates curl tar
WORKDIR /app

ARG MIGRATE_VERSION=4.7.1
ADD https://github.com/golang-migrate/migrate/releases/download/v${MIGRATE_VERSION}/migrate.linux-amd64.tar.gz /tmp/migrate.tar.gz
RUN tar -xzf /tmp/migrate.tar.gz -C /usr/local/bin \
  && mv /usr/local/bin/migrate.linux-amd64 /usr/local/bin/migrate \
  && chmod +x /usr/local/bin/migrate

COPY go.* ./
RUN go mod download && go mod verify

COPY . .
RUN make build

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /app

COPY --from=build /usr/local/bin/migrate /usr/local/bin/migrate
COPY --from=build /app/migrations ./migrations/
COPY --from=build /app/server ./server

ENTRYPOINT ["./server"]
