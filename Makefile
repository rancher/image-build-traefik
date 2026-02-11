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
TAG := v3.6.8$(BUILD_META)
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
# IID_FILE_FLAG is filled by ecm-distro-tools/action/publish-image
.PHONY: image-push-digest
image-push-digest:
	docker buildx build \
		${IID_FILE_FLAG} \
		--sbom=true \
		--attest type=provenance,mode=max \
		--progress=plain \
		--platform=$(TARGET_PLATFORMS) \
		--metadata-file metadata-$(subst /,-,$(REPO))-$(subst /,-,$(TARGET_PLATFORMS)).json \
		--output type=image,push-by-digest=true,name-canonical=true,push=true \
		--pull \
		--build-arg PKG=$(PKG) \
		--build-arg TAG=$(BTAG) \
		--tag $(REPO)/hardened-traefik .

.PHONY: image-scan
image-scan:
	trivy --severity $(SEVERITIES) --no-progress --ignore-unfixed $(REPO)/hardened-traefik:$(TAG)

.PHONY: manifest-push
manifest-push:
	docker buildx imagetools create \
		--tag $(REPO)/hardened-traefik:$(TAG) \
		$$(jq -r '.["containerimage.digest"]' metadata-$(subst /,-,$(REPO))-linux-amd64.json) \
		$$(jq -r '.["containerimage.digest"]' metadata-$(subst /,-,$(REPO))-linux-arm64.json)
ifdef IID_FILE
	@echo "Writing image digest to $(IID_FILE)"
	docker buildx imagetools inspect --format "{{json .Manifest}}" $(REPO)/hardened-traefik:$(TAG) | jq -r '.digest' > "$(IID_FILE)"
endif

.PHONY: log
log:
	@echo "TARGET_PLATFORMS=$(TARGET_PLATFORMS)"
	@echo "TAG=$(TAG)"
	@echo "BTAG=$(BTAG)"
	@echo "REPO=$(REPO)"
	@echo "SRC=$(SRC)"
	@echo "BUILD_META=$(BUILD_META)"
	@echo "UNAME_M=$(UNAME_M)"