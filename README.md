# InnoVest Microservices Deployment

This repository contains the Kubernetes deployment configurations for the InnoVest microservices platform, including automated deployment scripts and ArgoCD GitOps integration.


## Prerequisites

- **Docker Desktop** installed and running
- **Minikube** installed
- **kubectl** installed
- **Git** installed
- **Python 3.x** installed

## Quick Start

### 1. Start Minikube

```bash
# Start minikube with sufficient resources
minikube start --memory=4096 --cpus=2

# Enable ingress addon
minikube addons enable ingress

# Verify minikube is running
minikube status
```

### 2. Clone and Setup Repository

```bash
git clone https://github.com/InnoVest-Organization/Deployment.git
cd Deployment
```

### 3. Configure Services

Edit the `services.env` file to configure your microservices:

```env
# === successstory ===
SERVICE_NAME=successstory-microservice
IMAGE=docker.io/hashiniranaweera/innovest-successstory-microservice:latest
PORT=5007
NAMESPACE=innovest-dev

# === payment ===
SERVICE_NAME=payment-microservice
IMAGE=docker.io/hashiniranaweera/innovest-payment-microservice:latest
PORT=5003
NAMESPACE=innovest-dev
```

**Configuration Parameters:**
- `SERVICE_NAME`: Kubernetes service and deployment name
- `IMAGE`: Docker image URL (must be publicly accessible)
- `PORT`: Container port the service runs on
- `NAMESPACE`: Kubernetes namespace for deployment

### 4. Deploy Services

```bash
# Make deploy script executable (Windows)
bash deploy.sh

# Run deployment script
./deploy.sh

# Or run manually:
python generate_manifests.py
kubectl apply -f generated/ --recursive
kubectl apply -f generated/ingress.yaml
```

### 5. Verify Deployment

```bash
# Check namespace
kubectl get namespaces

# Check deployments
kubectl get deployments -n innovest-dev

# Check pods
kubectl get pods -n innovest-dev

# Check services
kubectl get services -n innovest-dev

# Check ingress
kubectl get ingress -n innovest-dev
```

## Configuration Details

### Services Configuration (`services.env`)

The `services.env` file defines your microservices. Each service requires exactly 4 lines:

```env
SERVICE_NAME=your-service-name
IMAGE=docker.io/username/your-image:tag
PORT=your-port
NAMESPACE=your-namespace
```

### Template Files

The deployment uses template files in the `base/` directory:

- `base/deployment.yaml` - Kubernetes Deployment template
- `base/service.yaml` - Kubernetes Service template
- `base/namespace.yaml` - Namespace definition

## Accessing Services


### Ingress (Production-like)

Services are accessible through ingress paths:
- Success Story: `http://localhost/api/successstory`
- Payment: `http://localhost/api/payments`

Get ingress IP:
```bash
minikube ip
```

## ArgoCD GitOps Setup

![screencapture-localhost-8080-applications-argocd-innovest-app-payment-2025-06-14-04_57_20 (1).png](Screenshots/screencapture-localhost-8080-applications-argocd-innovest-app-payment-2025-06-14-04_57_20%20%281%29.png)

### Install ArgoCD

```bash
# Create argocd namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

### Access ArgoCD UI

```bash
# Port forward ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Access ArgoCD at: `https://localhost:8080`
- Username: `admin`
- Password: (from command above)

### Create ArgoCD Applications

Create applications for each microservice:

```yaml
# payment-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: innovest-app-payment
  namespace: argocd
spec:
  destination:
    namespace: innovest-dev
    server: https://kubernetes.default.svc
  project: default
  source:
    path: generated/payment-microservice
    repoURL: https://github.com/InnoVest-Organization/Deployment
    targetRevision: main
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Apply the application:
```bash
kubectl apply -f innovest-app.yaml
```

##  Making Changes

### Updating Service Configuration

### Manual Sync with ArgoCD

```bash
# Force refresh ArgoCD application
kubectl annotate application innovest-app-payment -n argocd argocd.argoproj.io/refresh=normal

# Check sync status
kubectl get application innovest-app-payment -n argocd
```

### if not with the argocd-cli
```bash
# Login to ArgoCD
argocd login localhost:8080 --username admin --password <password> --insecure

# Sync application
argocd app sync innovest-app-payment
```


