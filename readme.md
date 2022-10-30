# tailscale/headscale derp server

For fast deployment of derp servers


# easy to deploy

Preparatory

- domain DNS record (A、AAAA or CNAME) e.g example.com
- certificate
- docker


Before you start you need to generate a certificate, which can be used certbot:

```shell
 docker run -it --rm --name certbot \
  -p 80:80 \
  -v "/etc/letsencrypt:/etc/letsencrypt"  \
  -v "/var/lib/letsencrypt:/var/lib/letsencrypt" \
  certbot/certbot certonly
```

Follow the prompts to generate the corresponding certificate.


deploy derp server:

```shell
docker run --restart always \
  --name derper -p 12345:443 -p 3478:3478/udp \
  -v /etc/letsencrypt/live/example.com/fullchain.pem:/app/certs/example.com.crt \
  -v /etc/letsencrypt/live/example.com/privkey.pem:/app/certs/example.com.key \  
  -e DERP_CERT_MODE=manual \
  -e DERP_DOMAIN=example.com \
  -d ghcr.io/slchris/derp-server:v1 
```


## easy to use


### headscale 


For headscale we need to modify the configuration to create a derp and then have headscale read that configuration.

```shell
vi /etc/headscale/derp.yaml
```

The contents:

```yaml
regions:
  900:
    regionid: 900
    regioncode: lv 
    regionname: Las Vegas, Nevada
    nodes:
      - name: 900a
        regionid: 900
        hostname: example.com
        stunport: 3478
        derpport: 12345
```

Modify the headscale main configuration as follows:

```yaml
# vi /etc/headscale/config.yaml
derp:
  # List of externally available DERP maps encoded in JSON
  #urls:
  #  - https://controlplane.tailscale.com/derpmap/default

  # Locally available DERP map files encoded in YAML
  #
  # This option is mostly interesting for people hosting
  # their own DERP servers:
  # https://tailscale.com/kb/1118/custom-derp-servers/
  #
  # paths:
  #   - /etc/headscale/derp-example.yaml
  paths:
    - /etc/headscale/derp.yaml

  # If enabled, a worker will be set up to periodically
  # refresh the given sources and update the derpmap
  # will be set up.
  auto_update_enabled: true

  # How often should we check for DERP updates?
  update_frequency: 24h
```

for test, we can comment out the following two lines:

```yaml
  #urls:
  #  - https://controlplane.tailscale.com/derpmap/default
``` 

Restart the headscale service:

```shell
systemctl restart headscale
```

Check the link status on the client:

```shell
tailscale netcheck
```