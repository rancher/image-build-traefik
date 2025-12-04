ARG GO_IMAGE=rancher/hardened-build-base:v1.24.11b1
FROM ${GO_IMAGE} AS builder
# setup required packages
RUN set -x && \
    apk --no-cache add \
    file \
    git \
    make \
    ca-certificates \
    tzdata \
    curl \
    tar

# setup the build
ARG PKG
ARG TAG
ARG TARGETARCH

# Download and extract Release src tarball, we do this instead of cloning because the
# static webui files are already generated and included in the tarball.
# Avoids needing to run a docker-in-docker build to generate the webui files.
RUN mkdir -p $GOPATH/src/${PKG}
RUN curl -fsSL "https://github.com/traefik/traefik/releases/download/${TAG}/traefik-${TAG}.src.tar.gz" | \
    tar -xzf - -C $GOPATH/src/${PKG}
WORKDIR $GOPATH/src/${PKG}

RUN --mount=type=cache,id=gomod,target=/go/pkg/mod go generate
# Extract the codename from the traefik Makefile
RUN --mount=type=cache,id=gomod,target=/go/pkg/mod \
    CODENAME=$(grep "^CODENAME.*?=" Makefile | cut -d'=' -f2 | tr -d ' ') && \
    GO_LDFLAGS="-w \
    -X github.com/traefik/traefik/v3/pkg/version.Version=${TAG} \
    -X github.com/traefik/traefik/v3/pkg/version.Codename=$CODENAME \
    -X github.com/traefik/traefik/v3/pkg/version.BuildDate=$(date -u '+%Y-%m-%d_%I:%M:%S%p')" \
    go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -o bin/traefik ./cmd/traefik
RUN go-assert-static.sh bin/*
RUN if [ "${TARGETARCH}" = "amd64" ]; then \
        go-assert-boring.sh bin/* ; \
    fi
RUN install -s bin/* /usr/local/bin
RUN traefik version

FROM scratch
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/
COPY --from=builder /usr/local/bin/traefik /

EXPOSE 80
VOLUME ["/tmp"]
ENTRYPOINT ["/traefik"]
