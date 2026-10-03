#!/usr/bin/env bash
set -Eeuo pipefail

SERVICE="${1:?service is required: vote|result|worker}"
IMAGE_REPOSITORY="${2:?image repository is required, e.g. myacr.azurecr.io/vote}"
IMAGE_TAG="${3:?image tag is required}"

case "$SERVICE" in
  vote)   MANIFEST="k8s-specifications/vote-deployment.yaml" ;;
  result) MANIFEST="k8s-specifications/result-deployment.yaml" ;;
  worker) MANIFEST="k8s-specifications/worker-deployment.yaml" ;;
  *) echo "Unsupported service: $SERVICE" >&2; exit 1 ;;
esac

[[ -f "$MANIFEST" ]] || { echo "Manifest not found: $MANIFEST" >&2; exit 1; }

NEW_IMAGE="${IMAGE_REPOSITORY}:${IMAGE_TAG}"

python3 - "$MANIFEST" "$NEW_IMAGE" <<'PY'
from pathlib import Path
import re
import sys

manifest = Path(sys.argv[1])
new_image = sys.argv[2]
text = manifest.read_text()

# The three application deployments each contain exactly one container image.
# Refuse to edit if that assumption is violated instead of silently changing
# the wrong image.
pattern = re.compile(r'^(\s*-\s*image:\s*)\S+\s*$', re.MULTILINE)
matches = list(pattern.finditer(text))
if len(matches) != 1:
    raise SystemExit(
        f"{manifest}: expected exactly one container image line; found {len(matches)}"
    )

updated = pattern.sub(lambda m: m.group(1) + new_image, text, count=1)
if updated == text:
    raise SystemExit(f"{manifest}: image was not changed")

manifest.write_text(updated)
print(f"Updated {manifest} -> {new_image}")
PY

git config user.email "azure-pipelines[bot]@users.noreply.azuredevops.com"
git config user.name "Azure Pipelines"

git add "$MANIFEST"

if git diff --cached --quiet; then
  echo "No manifest change to commit."
  exit 0
fi

git commit -m "ci: update ${SERVICE} image to ${IMAGE_TAG}"

BRANCH="$(git branch --show-current)"
if [[ -z "$BRANCH" ]]; then
  BRANCH="$(git rev-parse --abbrev-ref HEAD)"
fi

git push origin "HEAD:${BRANCH}"
