# make docker images


local_image:
	docker buildx build --platform linux/arm64,linux/amd64 -t derp-server:v1 . --load 


ghcr_image:
	docker buildx build --platform linux/arm64,linux/amd64 -t ghcr.io/slchris/derp-server:v1 . --push 
