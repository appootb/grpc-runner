FROM golang:1.17

ENV GO111MODULE on

# protoc-gen-go version: https://pkg.go.dev/google.golang.org/protobuf/cmd/protoc-gen-go
ENV PROTOC_GEN_GO_VER v1.27.1
# protoc-gen-go-grpc version: https://pkg.go.dev/google.golang.org/grpc/cmd/protoc-gen-go-grpc
ENV PROTOC_GEN_GO_GRPC_VER v1.1.0
# grpc-gateway version: https://github.com/grpc-ecosystem/grpc-gateway
ENV GRPC_GATEAY_VER v1.16.0
# custome generator version: https://github.com/appootb/grpc-gen
ENV CUSTOM_GEN_VER v1.3.1

RUN git clone https://github.com/appootb/substratum.git /go/src/github.com/appootb/substratum && \
	git clone https://github.com/googleapis/googleapis.git /go/src/github.com/googleapis/googleapis && \
	git clone -b ${GRPC_GATEAY_VER} https://github.com/grpc-ecosystem/grpc-gateway.git /go/src/github.com/grpc-ecosystem/grpc-gateway

RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@${PROTOC_GEN_GO_VER} && \
    go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@${PROTOC_GEN_GO_GRPC_VER} && \
	go install github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway@${GRPC_GATEAY_VER} && \
	go install github.com/grpc-ecosystem/grpc-gateway/protoc-gen-swagger@${GRPC_GATEAY_VER} && \
	go install github.com/appootb/grpc-gen/protoc-gen-ootb@${CUSTOM_GEN_VER} && \
	go install github.com/appootb/grpc-gen/protoc-gen-markdown@${CUSTOM_GEN_VER} && \
	go install github.com/appootb/grpc-gen/protoc-gen-validate@${CUSTOM_GEN_VER}

FROM debian:bullseye

# Protocol Buffers version: https://github.com/protocolbuffers/protobuf/releases/latest
ENV PROTOC_VER 3.18.1
# protoc-gen-grpc-java version: https://mvnrepository.com/artifact/io.grpc/protoc-gen-grpc-java
ENV JAVA_GRPC_VER 1.41.0
# protoc-gen-dart version: https://pub.dev/packages/protoc_plugin
ENV DART_GRPC_VER 20.0.0

# Install requirements
RUN apt update && apt install -y apt-transport-https make curl unzip

# protoc
RUN curl -OL https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VER}/protoc-${PROTOC_VER}-linux-aarch_64.zip && \
	unzip protoc-${PROTOC_VER}-linux-aarch_64.zip -d protoc3 && mv protoc3/bin/* /usr/local/bin/ && mv protoc3/include/* /usr/local/include/ && \
	rm -rf protoc-${PROTOC_VER}-linux-aarch_64.zip protoc3

# protoc-gen-grpc-java
RUN curl -OL https://repo1.maven.org/maven2/io/grpc/protoc-gen-grpc-java/${JAVA_GRPC_VER}/protoc-gen-grpc-java-${JAVA_GRPC_VER}-osx-aarch_64.exe && \
	mv protoc-gen-grpc-java-${JAVA_GRPC_VER}-osx-aarch_64.exe /usr/local/bin/protoc-gen-grpc-java && chmod +x /usr/local/bin/protoc-gen-grpc-java

# go binaries
COPY --from=0 /go/bin/* /usr/local/bin/

# GOPATH, proto including files required
COPY --from=0 /go/src/github.com/googleapis/googleapis /go/src/github.com/googleapis/googleapis
COPY --from=0 /go/src/github.com/appootb/substratum/proto/appootb /go/src/github.com/appootb/substratum/proto/appootb
COPY --from=0 /go/src/github.com/grpc-ecosystem/grpc-gateway/protoc-gen-swagger/options /go/src/github.com/grpc-ecosystem/grpc-gateway/protoc-gen-swagger/options

ENV GOPATH /go

WORKDIR /mnt
