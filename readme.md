# tailscale/headscale derp server

For fast deployment of derp servers


# easy to deploy


e.g. 

```shell
docker run --restart always \
  --name derper -p 12345:12345 -p 3478:3478/udp \
  -v $PWD/certs/:/app/certs \
  -e DERP_ADDR=:12345 \
  -e DERP_DOMAIN=xxxx \
  -d ghcr.io/slchris/derp-server:v1
```