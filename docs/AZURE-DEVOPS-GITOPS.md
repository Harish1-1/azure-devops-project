# Azure DevOps + ACR + AKS + Argo CD implementation

This document describes the integration added to the Docker Example Voting App.
The application source and its original local Docker/Kubernetes setup are kept intact.

## Architecture

Developer -> Azure DevOps -> Azure Pipeline -> ACR -> Git manifest update -> Argo CD -> AKS

The application itself is:

vote (Python) -> Redis -> worker (.NET) -> PostgreSQL -> result (Node.js)

## 1. Azure resources

Login:

```bash
az login
```

Create the resources with:

```bash
./scripts/create-azure-resources.sh <resource-group> <location> <acr-name> <aks-name>
```

The script attaches ACR to AKS. This means AKS can pull private ACR images using its Azure identity; no registry password needs to be committed into Kubernetes YAML.

## 2. Azure DevOps repository

Push this complete repository into an Azure DevOps Git repository.

The three pipelines are:

- `azure-pipelines-vote.yml`
- `azure-pipelines-result.yml`
- `azure-pipelines-worker.yml`

Create one Azure DevOps pipeline for each YAML file.

## 3. Self-hosted agent

The pipeline YAML expects an agent-pool variable named `agentPool`.

The agent must have:

- Docker Engine
- Git
- Python 3

For a self-hosted Linux agent, install Docker and give the Azure DevOps agent account permission to use Docker.

In Azure DevOps, create a variable:

```text
agentPool = <your agent pool name>
```

## 4. ACR service connection

Create an Azure Resource Manager/Docker registry service connection in Azure DevOps that can push to your ACR.

The default YAML value is:

```yaml
dockerRegistryServiceConnection: 'acr-service-connection'
```

Change it to the exact service-connection name if yours differs.

Also replace:

```yaml
containerRegistry: 'YOUR_ACR_NAME.azurecr.io'
```

with your real ACR login server.

## 5. CI flow

Example: developer changes `vote/app.py`.

The vote pipeline is triggered because its path filter is:

```yaml
paths:
  include:
    - vote/*
```

The pipeline:

1. Checks out the repository.
2. Builds the vote Docker image.
3. Pushes the image to ACR using `$(Build.BuildId)` as the tag.
4. Updates `k8s-specifications/vote-deployment.yaml`.
5. Commits the new image tag to Git.
6. Pushes the commit to `main`.

The same process exists independently for result and worker.

## 6. Why the manifest commit does not create an infinite pipeline loop

The pipelines only watch their application directories:

```text
vote/*
result/*
worker/*
```

The CI commit changes only:

```text
k8s-specifications/*
```

Therefore that Git commit does not retrigger the application CI pipeline.

## 7. Argo CD

Install Argo CD after AKS is ready:

```bash
./scripts/install-argocd.sh
```

For a private Azure DevOps repository, configure repository credentials without putting the PAT in Git:

```bash
./scripts/configure-argocd-repository.sh \
  'https://dev.azure.com/ORG/PROJECT/_git/REPOSITORY' \
  '<azure-devops-username>' \
  '<azure-devops-pat>'
```

Edit `argocd/application.yaml` and replace:

```text
https://dev.azure.com/YOUR_ORG/YOUR_PROJECT/_git/YOUR_REPOSITORY
```

with the actual repository URL.

Then:

```bash
kubectl apply -f argocd/application.yaml
```

Argo CD watches `k8s-specifications` and automatically synchronizes AKS.

## 8. Deployment flow

```text
Code change
   |
   v
Azure DevOps Git
   |
   v
Path-based Azure Pipeline
   |
   +---- Docker build
   |
   v
Azure Container Registry
   |
   v
Build.BuildId image tag
   |
   v
Kubernetes manifest updated
   |
   v
Git commit + push
   |
   v
Argo CD detects Git change
   |
   v
AKS synchronization
   |
   v
New application Pod
```

## 9. Important permissions

The Azure DevOps pipeline identity must be allowed to contribute/push to the repository because the CI stage commits the image-tag update.

Argo CD must have read access to the Azure DevOps repository.

AKS must have permission to pull from ACR. The resource setup script uses `az aks update --attach-acr` for this.

## 10. Validation

After deployment:

```bash
kubectl get pods
kubectl get svc
kubectl get deployments
kubectl get applications -n argocd
```

The upstream Kubernetes services expose the vote and result applications as NodePorts `31000` and `31001` respectively.

Check:

```bash
kubectl get nodes -o wide
kubectl get svc vote result
```

Then use the AKS node/public access method appropriate for your cluster/network to open the vote and result applications.
