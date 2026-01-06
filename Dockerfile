FROM --platform=$BUILDPLATFORM golang:1.25-alpine AS build
RUN apk add --no-cache git bash make ca-certificates
WORKDIR /src

COPY go.* ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download && go mod verify

COPY . .

ARG TARGETOS
ARG TARGETARCH

RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    CGO_ENABLED=0 GOOS="$TARGETOS" GOARCH="$TARGETARCH" make build

FROM --platform=$TARGETPLATFORM alpine:3.20
RUN apk add --no-cache ca-certificates
WORKDIR /app

COPY --from=build /src/server ./server
COPY --from=build /src/migrations ./migrations

ENTRYPOINT ["./server"]
