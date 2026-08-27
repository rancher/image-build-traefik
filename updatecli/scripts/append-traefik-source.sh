#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <traefik-tag> <source-sha256>" >&2
    exit 2
fi

tag="$1"
sha256="$2"
manifest="traefik-sources.json"

case "$tag" in
    v[0-9]*.[0-9]*.[0-9]*) ;;
    *)
        echo "invalid Traefik tag: $tag" >&2
        exit 1
        ;;
esac

existing_sha256="$(jq -r --arg tag "$tag" '.[$tag] // empty' "$manifest")"
if [ -n "$existing_sha256" ]; then
    if [ "$existing_sha256" = "$sha256" ]; then
        exit 0
    fi

    echo "source entry for $tag already exists with a different SHA-256" >&2
    exit 1
fi

if [ "$DRY_RUN" = "true" ]; then
    echo "would add $tag to $manifest"
    exit 0
fi

temporary_manifest="$(mktemp)"
trap 'rm -f "$temporary_manifest"' EXIT
jq --arg tag "$tag" --arg sha256 "$sha256" '. + {($tag): $sha256}' "$manifest" > "$temporary_manifest"
mv "$temporary_manifest" "$manifest"
printf 'added %s to %s\n' "$tag" "$manifest"
