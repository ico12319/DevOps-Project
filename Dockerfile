FROM --platform=$BUILDPLATFORM golang:alpine AS build
RUN apk add --no-cache git bash make ca-certificates curl tar
WORKDIR /app

ARG TARGETOS
ARG TARGETARCH

ARG MIGRATE_VERSION=4.19.1

RUN set -eux; \
  FILE="migrate.${TARGETOS}-${TARGETARCH}.tar.gz"; \
  curl -fsSL "https://github.com/golang-migrate/migrate/releases/download/v${MIGRATE_VERSION}/${FILE}" -o /tmp/migrate.tar.gz; \
  tar -xzf /tmp/migrate.tar.gz -C /usr/local/bin; \
  mv "/usr/local/bin/migrate.${TARGETOS}-${TARGETARCH}" /usr/local/bin/migrate; \
  chmod +x /usr/local/bin/migrate; \
  ls -la /usr/local/bin | grep migrate

COPY go.* ./
RUN --mount=type=cache,target=/go/pkg/mod \
  go mod download && go mod verify

COPY . .

RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH make build

FROM --platform=$TARGETPLATFORM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /app

COPY --from=build /usr/local/bin/migrate /usr/local/bin/migrate
COPY --from=build /app/migrations ./migrations/
COPY --from=build /app/server ./server

ENTRYPOINT ["./server"]
