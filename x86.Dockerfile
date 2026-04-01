FROM alpine:3.23.3 AS base

RUN apk add --no-cache \
    libc6-compat \
    libuv \
    libuv-dev \
    libstdc++ \
    g++ \
    curl \
    libffi-dev \
    zlib-dev

# LLVM 20 and LLD 20 from Edge
RUN apk add --no-cache \
    --repository=http://dl-cdn.alpinelinux.org/alpine/edge/main \
    --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community \
    llvm20-libs \
    lld20-libs \
    lld20

FROM base AS install
WORKDIR /app

RUN curl -fsSL -o c3-linux-musl.tar.gz \
    https://github.com/c3lang/c3c/releases/download/v0.7.10/c3-linux-musl.tar.gz && \
    tar -xzf c3-linux-musl.tar.gz && \
    rm c3-linux-musl.tar.gz

RUN mv c3/c3c /usr/local/bin/c3c && \
    mkdir -p /usr/local/lib/c3 && \
    mv c3/lib/* /usr/local/lib/c3/

FROM base AS build
WORKDIR /app

# Copy only the necessary compiler/binary from the install stage
COPY --from=install /usr/local/bin/c3c /usr/local/bin/c3c
COPY --from=install /usr/local/lib/c3 /usr/local/lib/c3
COPY . .

RUN c3c build web


FROM base AS runner
WORKDIR /app
COPY --from=build /app/docs /app/docs
COPY --from=build /app/build/web /app/ 

EXPOSE 3000

CMD [ "./web" ]