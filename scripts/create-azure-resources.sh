#!/usr/bin/env bash
set -Eeuo pipefail

# Creates the Azure resources used by the project.
# Run after: az login

RESOURCE_GROUP="${1:?resource group is required}"
LOCATION="${2:?location is required, e.g. centralindia}"
ACR_NAME="${3:?ACR name is required; must be globally unique and alphanumeric}"
AKS_NAME="${4:?AKS name is required}"

az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
az acr create --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" --sku Basic
az aks create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_NAME" \
  --node-count 1 \
  --enable-managed-identity \
  --generate-ssh-keys

az aks update \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_NAME" \
  --attach-acr "$ACR_NAME"

az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_NAME" \
  --overwrite-existing

echo "Azure resources are ready."
