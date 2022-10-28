FROM golang as builder

WORKDIR /app 

# Install tailscale derper
# https://tailscale.com/kb/1118/custom-derp-servers/

RUN git clone https://github.com/tailscale/tailscale/ && \
    cd tailscale && \
    CGO_ENABLED=0 go build -o derper  ./cmd/derper/


FROM busybox

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

WORKDIR /app

COPY --from=builder /app/tailscale/derper .


CMD /app/derper -hostname=$DERP_DOMAIN \
    -certmode=$DERP_CERT_MODE \
    -certdir=$DERP_CERT_DIR \
    -a=$DERP_ADDR \
    -stun=$DERP_STUN  \
    -http-port=$DERP_HTTP_PORT \
    -verify-clients=$DERP_VERIFY_CLIENTS