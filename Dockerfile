FROM alpine:3.23.3 AS base

RUN apk add --no-cache \
    build-base \
    libc6-compat \
    libuv \
    libuv-dev \
    libstdc++ \
    g++ \
    curl \
    libffi-dev \
    zlib-dev \
    cmake   \
    ninja   \
    git

# LLVM 20 and all required build dependencies from Edge
RUN apk add --no-cache \
    --repository=http://dl-cdn.alpinelinux.org/alpine/edge/main \
    --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community \
    # Existing packages...
    llvm20-dev \
    llvm20-static \
    llvm20-test-utils \
    llvm20-gtest \
    # LLD and Clang
    lld20-dev \
    clang20-dev \
    clang20-static \
    # Required system libs for LLVM 20 linking
    zstd-dev \
    zlib-dev \
    libxml2-dev \
    curl-dev

FROM base AS install
WORKDIR /app
RUN git clone https://github.com/c3lang/c3c

RUN cd c3c && \
    git fetch --depth 1 origin 71c5d5bafd700d7d2f2a0fe282fc93a7420faf9e && \
    git reset --hard FETCH_HEAD && \
    mkdir build && \
    cd build && \
    cmake -G Ninja \
    -DC3_LINK_DYNAMIC=ON \
    -DLLVM_DIR=/usr/lib/llvm20/lib/cmake/llvm \
    -DMLIR_DIR=/usr/lib/llvm20/lib/cmake/mlir \
    .. && \    
    ninja && \
    cp c3c /usr/local/bin/c3c && \
    mkdir -p /usr/local/lib/c3 && \
    cp -r lib/* /usr/local/lib/c3/

FROM base AS build
WORKDIR /app

# Copy only the necessary compiler/binary from the install stage
COPY --from=install /usr/local/bin/c3c /usr/local/bin/c3c
COPY --from=install /usr/local/lib/c3 /usr/local/lib/c3
COPY . .

RUN c3c build web


FROM alpine:3.23.3 AS runner
RUN apk add --no-cache libuv curl

WORKDIR /app
COPY --from=build /app/docs /app/docs
COPY --from=build /app/build/web /app/ 

EXPOSE 3000

CMD [ "./web" ]