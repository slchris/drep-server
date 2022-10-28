FROM golang as builder

WORKDIR /app 

# Install tailscale derper
# https://tailscale.com/kb/1118/custom-derp-servers/

RUN git clone https://github.com/tailscale/tailscale/ && \
    cd tailscale && \
    CGO_ENABLED=0 go build  ./cmd/derper/


FROM alpine:3.16.0

LABEL maintainer="Tailscale/Headscale Derp server <chris@lesscrowds.org>"

ENV LANG C.UTF-8
# 
ENV DERP_DOMAIN example.com
ENV DERP_CERT_MODE letsencrypt
ENV DERP_CERT_DIR /app/certs
ENV DERP_ADDR :443
ENV DERP_STUN true
ENV DERP_HTTP_PORT 80
ENV DERP_VERIFY_CLIENTS false
# User
ENV USER_ID=114514
ENV GROUP_ID=114514
ENV USER_NAME=homo
ENV GROUP_NAME=homo


WORKDIR /app

RUN apk update && \
    apk add --no-cache bash \
    tzdata && \
    rm -rf /var/cache/apk/*

COPY --from=builder /app/tailscale/derper .

RUN addgroup -g $USER_ID $GROUP_NAME && \
    adduser --shell /bin/bash --disabled-password \
    -h /app --uid $USER_ID --ingroup $GROUP_NAME $USER_NAME && \
    mkdir -pv /app/certs && \
    chown -R ${USER_NAME}:${GROUP_NAME}  /app

USER ${USER_NAME} 


CMD /app/derper -hostname=$DERP_DOMAIN \
    -certmode=$DERP_CERT_MODE \
    -certdir=$DERP_CERT_DIR \
    -a=$DERP_ADDR \
    -stun=$DERP_STUN  \
    -http-port=$DERP_HTTP_PORT \
    -verify-clients=$DERP_VERIFY_CLIENTS