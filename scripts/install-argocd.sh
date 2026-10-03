#!/usr/bin/env bash
set -Eeuo pipefail

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl -n argocd rollout status deployment/argocd-server --timeout=300s
kubectl -n argocd patch svc argocd-server \
  -p '{"spec":{"type":"NodePort"}}'

echo
echo "Argo CD is installed."
echo "Server service:"
kubectl get svc argocd-server -n argocd

echo
echo "Initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 --decode
echo
