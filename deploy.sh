#!/bin/bash

set -e

# Colors
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
NC="\033[0m"

echo -e "${GREEN}=== Innovest Microservices Deployment Script ===${NC}"

# Check services.env
if [[ ! -f "services.env" ]]; then
  echo -e "${RED}[ERROR] Missing services.env file.${NC}"
  exit 1
fi

# Get NAMESPACE from services.env
NAMESPACE=$(grep -m1 NAMESPACE services.env | cut -d '=' -f2 | xargs)
if [[ -z "$NAMESPACE" ]]; then
  echo -e "${RED}[ERROR] NAMESPACE not found in services.env.${NC}"
  exit 1
fi

# Handle --clean
if [[ "$1" == "--clean" ]]; then
  echo -e "${RED}[!] Cleaning existing resources in namespace: $NAMESPACE${NC}"
  kubectl delete all --all -n "$NAMESPACE" || true
  kubectl delete deployments -n "$NAMESPACE" || true
  kubectl delete ingress innovest-ingress -n "$NAMESPACE" || true
  rm -rf generated/
  echo -e "${GREEN}[✔] Clean complete.${NC}"
fi

echo -e "${GREEN}[1/5] Ensuring namespace '$NAMESPACE' exists...${NC}"
kubectl get ns "$NAMESPACE" >/dev/null 2>&1 || kubectl apply -f base/namespace.yaml

if ! kubectl get deployment ingress-nginx-controller -n ingress-nginx >/dev/null 2>&1; then
  echo -e "${GREEN}[2/5] Installing NGINX Ingress Controller...${NC}"
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml
else
  echo -e "${YELLOW}[2/5] NGINX Ingress Controller already installed. Skipping re-apply.${NC}"
fi

# Wait for ingress controller to be ready
echo -e "${YELLOW}⏳ Waiting for ingress controller to be ready...${NC}"
kubectl wait --namespace ingress-nginx \
  --for=condition=Ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s || echo -e "${YELLOW}⚠️ Timeout waiting for ingress controller. You can still access manually later.${NC}"

echo -e "${GREEN}[3/5] Generating manifests from services.env...${NC}"
python generate_manifests.py

echo -e "${GREEN}[4/5] Applying microservice manifests...${NC}"
kubectl apply -f generated/ --recursive

echo -e "${GREEN}[5/5] Applying ingress manifest...${NC}"
kubectl apply -f generated/ingress.yaml

echo -e "${GREEN}[✔] Deployment complete!${NC}"
echo -e "${GREEN}Access your services via Ingress: http://localhost/{API_PATH}/...${NC}"

# Optional port-forward
read -p $'\n Do you want to port-forward ingress to localhost:80? (y/n) ' answer
if [[ "$answer" == "y" ]]; then
  echo -e "${GREEN}Forwarding port 80 to ingress-nginx-controller service...${NC}"
  kubectl port-forward service/ingress-nginx-controller 80:80 -n ingress-nginx
else
  echo -e "${YELLOW} Skipping port-forward. You can run it manually if needed:${NC}"
  echo "kubectl port-forward service/ingress-nginx-controller 80:80 -n ingress-nginx"
fi
