#!/bin/bash
set -e

NAMESPACE="${NAMESPACE:-projectsveltos}"
RELEASE_NAME="${RELEASE_NAME:-k8s-cleaner}"

usage() {
    cat << EOF
Install k8s-cleaner via Helm

Usage: $0 [OPTIONS]

OPTIONS:
    -n, --namespace NAMESPACE    Namespace to install (default: projectsveltos)
    -r, --release RELEASE         Helm release name (default: k8s-cleaner)
    --values VALUES_FILE         Custom values file
    -u, --upgrade                 Upgrade existing installation
    -h, --help                    Show this help

EXAMPLES:
    $0                           # Install in projectsveltos namespace
    $0 -n myns                   # Install in custom namespace
    $0 --upgrade                 # Upgrade existing installation
EOF
    exit 1
}

UPGRADE=false
VALUES_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -r|--release)
            RELEASE_NAME="$2"
            shift 2
            ;;
        --values)
            VALUES_FILE="$2"
            shift 2
            ;;
        -u|--upgrade)
            UPGRADE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

echo "Installing k8s-cleaner..."

# Add Helm repo if not present
if ! helm repo list | grep -q projectsveltos; then
    echo "Adding projectsveltos Helm repo..."
    helm repo add projectsveltos https://projectsveltos.github.io/helm-charts
fi

helm repo update

# Install or upgrade
if [ "$UPGRADE" = true ]; then
    echo "Upgrading k8s-cleaner in namespace: $NAMESPACE"
    if [ -n "$VALUES_FILE" ]; then
        helm upgrade "$RELEASE_NAME" projectsveltos/k8s-cleaner \
            --namespace "$NAMESPACE" \
            --values "$VALUES_FILE"
    else
        helm upgrade "$RELEASE_NAME" projectsveltos/k8s-cleaner \
            --namespace "$NAMESPACE"
    fi
else
    echo "Installing k8s-cleaner in namespace: $NAMESPACE"
    kubectl create namespace "$NAMESPACE" 2>/dev/null || true
    
    if [ -n "$VALUES_FILE" ]; then
        helm install "$RELEASE_NAME" projectsveltos/k8s-cleaner \
            --namespace "$NAMESPACE" \
            --create-namespace \
            --values "$VALUES_FILE"
    else
        helm install "$RELEASE_NAME" projectsveltos/k8s-cleaner \
            --namespace "$NAMESPACE" \
            --create-namespace
    fi
fi

echo ""
echo "Waiting for deployment..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=k8s-cleaner \
    -n "$NAMESPACE" --timeout=120s 2>/dev/null || true

echo ""
echo "Installation complete!"
echo "Run: kubectl get pods -n $NAMESPACE"
echo "Run: kubectl get cleaner -A"
