# tailscale/headscale drep server

For fast deployment of drep servers


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


deploy drep server:

```shell
docker run --restart always \
  --name dreper -p 12345:443 -p 3478:3478/udp \
  -v /etc/letsencrypt/live/example.com/fullchain.pem:/app/certs/example.com.crt \
  -v /etc/letsencrypt/live/example.com/privkey.pem:/app/certs/example.com.key \  
  -e drep_CERT_MODE=manual \
  -e drep_DOMAIN=example.com \
  -d ghcr.io/slchris/drep-server:v1 
```


## easy to use


### headscale 


For headscale we need to modify the configuration to create a drep and then have headscale read that configuration.

```shell
vi /etc/headscale/drep.yaml
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
        drepport: 12345
```

Modify the headscale main configuration as follows:

```yaml
# vi /etc/headscale/config.yaml
drep:
  # List of externally available drep maps encoded in JSON
  #urls:
  #  - https://controlplane.tailscale.com/drepmap/default

  # Locally available drep map files encoded in YAML
  #
  # This option is mostly interesting for people hosting
  # their own drep servers:
  # https://tailscale.com/kb/1118/custom-drep-servers/
  #
  # paths:
  #   - /etc/headscale/drep-example.yaml
  paths:
    - /etc/headscale/drep.yaml

  # If enabled, a worker will be set up to periodically
  # refresh the given sources and update the drepmap
  # will be set up.
  auto_update_enabled: true

  # How often should we check for drep updates?
  update_frequency: 24h
```

for test, we can comment out the following two lines:

```yaml
  #urls:
  #  - https://controlplane.tailscale.com/drepmap/default
``` 

Restart the headscale service:

```shell
systemctl restart headscale
```

Check the link status on the client:

```shell
tailscale netcheck
```