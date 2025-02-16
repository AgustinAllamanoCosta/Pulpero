FROM alpine:latest
WORKDIR /app
COPY lua/pulpero/core core

RUN apk update && \
    apk add --no-cache \
    build-base \
    readline-dev \
    unzip \
    curl \
    lua5.3 \
    lua5.3-dev \
    openssl-dev \
    luarocks

RUN luarocks install luafilesystem milua

EXPOSE 8080
CMD ["lua5.3","core/init.lua"]
