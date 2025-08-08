# Step 1: Build Go API
FROM golang:1.24.5-bullseye@sha256:62ba6b19de03e891f7fa1001326bd48411f2626ff35e7ba5b9d890711ce581d9 AS api-build
ARG GIT_COMMIT

WORKDIR /src/wallet-backend
COPY go.mod go.sum ./
RUN go mod download
COPY . ./
RUN go build -o /bin/wallet-backend -ldflags "-X main.GitCommit=$GIT_COMMIT" .

# Use the official stellar/soroban-rpc image as the base
FROM stellar/soroban-rpc

# Install bash or sh
RUN apt-get update && apt-get install -y bash


# Step 2: Install Stellar Core and copy over app binary
FROM ubuntu:jammy@sha256:5e41972c0cdee05640f3ed85ad5e7dca92c5a589ced43badaf14d81466f891ae AS core-build

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl wget gnupg apt-utils gpg && \
    curl -sSL https://apt.stellar.org/SDF.asc | gpg --dearmor >/etc/apt/trusted.gpg.d/SDF.gpg && \
    echo "deb https://apt.stellar.org jammy stable" >/etc/apt/sources.list.d/SDF.list && \
    echo "deb https://apt.stellar.org jammy testing" >/etc/apt/sources.list.d/SDF-testing.list && \
    echo "deb https://apt.stellar.org jammy unstable" >/etc/apt/sources.list.d/SDF-unstable.list

COPY --from=api-build /bin/wallet-backend /app/
COPY scripts/startup.sh /app/startup.sh
RUN chmod +x /app/startup.sh

EXPOSE 8001
WORKDIR /app
ENTRYPOINT ["/app/startup.sh"]
