# rancher/hardened-traefik


This repository created a hardened, FIPS 140-2 compatible, binary version of [Traefik](https://github.com/traefik/traefik) and deploys it in a scratch image.

## Build

```sh
TAG=v3.7.12-build$(date +%Y%m%d) make image-build
```

## Out-Of-Band Releases

[`traefik-sources.json`](traefik-sources.json) records every Traefik source
version and its source tarball SHA-256. The source archive URL is derived from
the version, and each image build verifies the archive against this checksum.

To release a version already recorded in this file, create a GitHub Release with
a tag such as `v3.7.10-build20260827`. The build derives the upstream source tag
as `v3.7.10`, obtains its SHA-256 from the manifest, and publishes amd64 and
arm64 images.