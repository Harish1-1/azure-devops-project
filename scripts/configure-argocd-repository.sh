#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="${1:?Azure DevOps repository URL is required}"
USERNAME="${2:?Azure DevOps username is required}"
PAT="${3:?Azure DevOps PAT is required}"

command -v argocd >/dev/null || { echo "argocd CLI is required" >&2; exit 1; }

# PAT is supplied as a command argument only for this invocation and is not
# written into the Git repository.
argocd repo add "$REPO_URL" \
  --username "$USERNAME" \
  --password "$PAT"

echo "Argo CD repository credentials configured."
