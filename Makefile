SEVERITIES = HIGH,CRITICAL

UNAME_M = $(shell uname -m)
ifndef TARGET_PLATFORMS
	ifeq ($(UNAME_M), x86_64)
		TARGET_PLATFORMS:=linux/amd64
	else ifeq ($(UNAME_M), aarch64)
		TARGET_PLATFORMS:=linux/arm64
	else 
		TARGET_PLATFORMS:=linux/$(UNAME_M)
	endif
endif

REPO ?= rancher
PKG ?= github.com/traefik/traefik/v3
BUILD_META=-build$(shell date +%Y%m%d)
TAG ?= ${GITHUB_ACTION_TAG}

ifeq ($(TAG),)
TAG := v3.5.0$(BUILD_META)
endif

ifeq (,$(filter %$(BUILD_META),$(TAG)))
$(error TAG needs to end with build metadata: $(BUILD_META))
endif

BTAG := $(shell echo $(TAG) | sed 's/-build.*//')

.PHONY: image-build
image-build:
	docker buildx build \
		--progress=plain \
		--platform=$(TARGET_PLATFORMS) \
		--pull \
		--build-arg PKG=$(PKG) \
		--build-arg TAG=$(BTAG) \
		--tag $(REPO)/hardened-traefik:$(TAG) \
		--load .

# Note the TAG is just the repo/image when pushing by digest
.PHONY: image-push-digest
image-push-digest:
	docker buildx build \
		--progress=plain \
		--platform=$(TARGET_PLATFORMS) \
		--metadata-file metadata-$(subst /,-,$(TARGET_PLATFORMS)).json \
		--output type=image,push-by-digest=true,name-canonical=true,push=true \
		--pull \
		--build-arg PKG=$(PKG) \
		--build-arg TAG=$(BTAG) \
		--tag $(REPO)/hardened-traefik .

.PHONY: image-scan
image-scan:
	trivy --severity $(SEVERITIES) --no-progress --ignore-unfixed $(REPO)/hardened-traefik:$(TAG)

# Pushes manifests for the provided TARGET_PLATFORMS
.PHONY: manifest-push
manifest-push:
	$(eval AMD64_DIGEST := $(if $(findstring linux/amd64,$(TARGET_PLATFORMS)),$(shell jq -r '.["containerimage.digest"]' metadata-linux-amd64.json),))
	$(eval ARM64_DIGEST := $(if $(findstring linux/arm64,$(TARGET_PLATFORMS)),$(shell jq -r '.["containerimage.digest"]' metadata-linux-arm64.json),))
	docker buildx imagetools create \
		--tag $(REPO)/hardened-traefik:$(TAG) \
		$(AMD64_DIGEST) \
		$(ARM64_DIGEST)

.PHONY: log
log:
	@echo "TARGET_PLATFORMS=$(TARGET_PLATFORMS)"
	@echo "TAG=$(TAG)"
	@echo "BTAG=$(BTAG)"
	@echo "REPO=$(REPO)"
	@echo "SRC=$(SRC)"
	@echo "BUILD_META=$(BUILD_META)"
	@echo "UNAME_M=$(UNAME_M)"