#
# Go binaries
FROM --platform=$TARGETPLATFORM golang:1.18 AS go

ENV GO111MODULE on

# protoc-gen-go version: https://pkg.go.dev/google.golang.org/protobuf/cmd/protoc-gen-go
ENV PROTOC_GEN_GO_VER v1.27.1
# protoc-gen-go-grpc version: https://pkg.go.dev/google.golang.org/grpc/cmd/protoc-gen-go-grpc
ENV PROTOC_GEN_GO_GRPC_VER v1.1.0
# grpc-gateway version: https://github.com/grpc-ecosystem/grpc-gateway/releases/latest
ENV GRPC_GATEWAY_VER v1.16.0
# custome generator version: https://github.com/appootb/grpc-gen/releases/latest
ENV CUSTOM_GEN_VER v1.3.1

RUN git clone https://github.com/appootb/substratum.git /go/src/github.com/appootb/substratum && \
	git clone https://github.com/googleapis/googleapis.git /go/src/github.com/googleapis/googleapis && \
	git clone -b ${GRPC_GATEWAY_VER} https://github.com/grpc-ecosystem/grpc-gateway.git /go/src/github.com/grpc-ecosystem/grpc-gateway

RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@${PROTOC_GEN_GO_VER} && \
    go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@${PROTOC_GEN_GO_GRPC_VER} && \
	go install github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway@${GRPC_GATEWAY_VER} && \
	go install github.com/grpc-ecosystem/grpc-gateway/protoc-gen-swagger@${GRPC_GATEWAY_VER} && \
	go install github.com/appootb/grpc-gen/protoc-gen-ootb@${CUSTOM_GEN_VER} && \
	go install github.com/appootb/grpc-gen/protoc-gen-markdown@${CUSTOM_GEN_VER} && \
	go install github.com/appootb/grpc-gen/protoc-gen-validate@${CUSTOM_GEN_VER}

#
# Swift
FROM --platform=$TARGETPLATFORM swift:5.6-focal AS swift

# protoc-gen-swift version: https://github.com/apple/swift-protobuf/releases/latest
ENV SWIFT_PLUGIN_VER 1.19.0

# Compile protoc-gen-swift
RUN git clone -b ${SWIFT_PLUGIN_VER} https://github.com/apple/swift-protobuf && cd swift-protobuf && \
	swift build --static-swift-stdlib -c release

#
# CSharp
FROM --platform=$TARGETPLATFORM mcr.microsoft.com/dotnet/sdk:6.0-focal AS csharp

ARG TARGETPLATFORM

# grpc_csharp_plugin version: https://www.nuget.org/packages/Grpc.Tools
ENV CS_PLUGIN_VER 2.41.0

RUN case ${TARGETPLATFORM} in \
         "linux/amd64") CS_ARCH=x64 ;; \
         "linux/arm64") CS_ARCH=arm64 ;; \
    esac && \
    cd /root && dotnet new console && \
	dotnet add package Grpc.Tools --version ${CS_PLUGIN_VER} && \
    cp /root/.nuget/packages/grpc.tools/${CS_PLUGIN_VER}/tools/linux_${CS_ARCH}/grpc_csharp_plugin /usr/local/bin/grpc_csharp_plugin

#
# Downloads
FROM --platform=$TARGETPLATFORM ubuntu:focal AS binary

# Protocol Buffers version: https://github.com/protocolbuffers/protobuf/releases/latest
ENV PROTOC_VER 3.18.1
# protoc-gen-grpc-java version: https://mvnrepository.com/artifact/io.grpc/protoc-gen-grpc-java
ENV JAVA_GRPC_VER 1.41.0
# protoc-gen-grpc-web version: https://github.com/grpc/grpc-web/releases/latest
ENV WEB_GRPC_VER 1.2.1
# Dart SDK version: https://dart.dev/get-dart/archive
ENV DART_SDK_VER 2.17.3

ARG TARGETPLATFORM

RUN apt update && apt install -y apt-transport-https curl unzip

# protoc
RUN case ${TARGETPLATFORM} in \
         "linux/amd64") PROTOC_ARCH=x86_64 ;; \
         "linux/arm64") PROTOC_ARCH=aarch_64 ;; \
    esac && \
    curl -OL https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VER}/protoc-${PROTOC_VER}-linux-${PROTOC_ARCH}.zip; \
    unzip protoc-${PROTOC_VER}-linux-${PROTOC_ARCH}.zip -d protoc3

# Dart SDK
RUN case ${TARGETPLATFORM} in \
         "linux/amd64") DART_ARCH=x64 ;; \
         "linux/arm64") DART_ARCH=arm64 ;; \
    esac && \
    curl -OL https://storage.googleapis.com/dart-archive/channels/stable/release/${DART_SDK_VER}/sdk/dartsdk-linux-${DART_ARCH}-release.zip; \
    unzip dartsdk-linux-${DART_ARCH}-release.zip -d dart

# protoc-gen-grpc-java
RUN case ${TARGETPLATFORM} in \
         "linux/amd64") JAVA_ARCH=x86_64 ;; \
         "linux/arm64") JAVA_ARCH=aarch_64 ;; \
    esac && \
    curl -OL https://repo1.maven.org/maven2/io/grpc/protoc-gen-grpc-java/${JAVA_GRPC_VER}/protoc-gen-grpc-java-${JAVA_GRPC_VER}-linux-${JAVA_ARCH}.exe && \
	mv protoc-gen-grpc-java-${JAVA_GRPC_VER}-linux-${JAVA_ARCH}.exe /usr/local/bin/protoc-gen-grpc-java && chmod +x /usr/local/bin/protoc-gen-grpc-java

# protoc-gen-grpc-web
# TODO no arm64 relase binary
#RUN curl -OL https://github.com/grpc/grpc-web/releases/download/${WEB_GRPC_VER}/protoc-gen-grpc-web-${WEB_GRPC_VER}-linux-x86_64 && \
#	mv protoc-gen-grpc-web-${WEB_GRPC_VER}-linux-x86_64 /usr/local/bin/protoc-gen-grpc-web && chmod +x /usr/local/bin/protoc-gen-grpc-web

#
# Runner
FROM --platform=$TARGETPLATFORM ubuntu:focal

# protoc-gen-dart version: https://pub.dev/packages/protoc_plugin
ENV DART_GRPC_VER 20.0.0

ENV PATH /usr/lib/dart/bin:$PATH

RUN apt -q update && apt -q install -y apt-transport-https make && rm -r /var/lib/apt/lists/*

# Go binaries
COPY --from=go /go/bin/* /usr/local/bin/

# GOPATH, proto including files required
COPY --from=go /go/src/github.com/googleapis/googleapis /go/src/github.com/googleapis/googleapis
COPY --from=go /go/src/github.com/appootb/substratum/proto/appootb /go/src/github.com/appootb/substratum/proto/appootb
COPY --from=go /go/src/github.com/grpc-ecosystem/grpc-gateway/protoc-gen-swagger/options /go/src/github.com/grpc-ecosystem/grpc-gateway/protoc-gen-swagger/options

# protoc-gen-swift
COPY --from=swift /swift-protobuf/.build/release/protoc-gen-swift /usr/local/bin/protoc-gen-swift

# grpc_csharp_plugin
COPY --from=csharp /usr/local/bin/grpc_csharp_plugin /usr/local/bin/grpc_csharp_plugin

# protoc
COPY --from=binary /protoc3/bin/* /usr/local/bin/
COPY --from=binary /protoc3/include/* /usr/local/include/

# protoc-gen-grpc-java
COPY --from=binary /usr/local/bin/protoc-gen-grpc-java /usr/local/bin/protoc-gen-grpc-java

# protoc-gen-dart
COPY --from=binary /dart/dart-sdk/ /usr/lib/dart/

RUN dart pub global activate protoc_plugin ${DART_GRPC_VER} && ln -s /root/.pub-cache/bin/protoc-gen-dart /usr/local/bin/

WORKDIR /mnt
