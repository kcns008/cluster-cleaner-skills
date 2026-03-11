#!/bin/bash
set -e

NAMESPACE="${NAMESPACE:-projectsveltos}"
VERSION="${VERSION:-v0.19.1}"
MANIFEST_URL="https://raw.githubusercontent.com/gianlucam76/k8s-cleaner/main/manifest/manifest.yaml"

usage() {
    cat << EOF
Install k8s-cleaner using kubectl with raw manifests

Usage: $0 [OPTIONS]

OPTIONS:
    -n, --namespace NAMESPACE    Namespace to install (default: projectsveltos)
    -v, --version VERSION       k8s-cleaner version (default: v0.19.1)
    -m, --manifest URL          Custom manifest URL
    -u, --upgrade               Upgrade existing installation
    -d, --uninstall             Uninstall k8s-cleaner
    -h, --help                  Show this help

EXAMPLES:
    $0                           # Install latest version
    $0 -n myns                   # Install in custom namespace
    $0 -v v0.18.0                # Install specific version
    $0 --upgrade                 # Upgrade existing installation
    $0 --uninstall               # Uninstall k8s-cleaner
EOF
    exit 1
}

UNINSTALL=false
UPGRADE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -m|--manifest)
            MANIFEST_URL="$2"
            shift 2
            ;;
        -u|--upgrade)
            UPGRADE=true
            shift
            ;;
        -d|--uninstall)
            UNINSTALL=true
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

if [ "$UNINSTALL" = true ]; then
    echo "Uninstalling k8s-cleaner..."
    echo "Note: This will NOT delete Cleaner/Report custom resources"
    echo ""
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    # Try to delete from different possible manifest URLs
    for version in v0.19.1 v0.18.0 v0.17.0; do
        url="https://raw.githubusercontent.com/gianlucam76/k8s-cleaner/$version/manifest/manifest.yaml"
        curl -sfL "$url" > /dev/null 2>&1 && break
    done
    
    # Delete deployment
    echo "Deleting Deployment..."
    kubectl delete deployment k8s-cleaner-controller -n "$NAMESPACE" --ignore-not-found=true 2>/dev/null || true
    
    # Delete RBAC
    echo "Deleting RBAC..."
    kubectl delete clusterrole k8s-cleaner-controller-role --ignore-not-found=true 2>/dev/null || true
    kubectl delete clusterrolebinding k8s-cleaner-controller-rolebinding --ignore-not-found=true 2>/dev/null || true
    kubectl delete clusterrole k8s-cleaner-metrics-reader --ignore-not-found=true 2>/dev/null || true
    kubectl delete clusterrole k8s-cleaner-proxy-role --ignore-not-found=true 2>/dev/null || true
    
    # Delete ServiceAccount
    echo "Deleting ServiceAccount..."
    kubectl delete sa k8s-cleaner-controller -n "$NAMESPACE" --ignore-not-found=true 2>/dev/null || true
    
    # Delete namespace (optional - only if it's the default)
    if [ "$NAMESPACE" = "projectsveltos" ]; then
        echo "Keeping namespace $NAMESPACE (contains CRDs)"
    fi
    
    echo "Uninstall complete."
    exit 0
fi

echo "Installing k8s-cleaner version: $VERSION"
echo "Namespace: $NAMESPACE"
echo ""

# Check kubectl availability
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed"
    exit 1
fi

# Check cluster connectivity
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: Cannot connect to Kubernetes cluster"
    exit 1
fi

# Check if already installed
EXISTING=$(kubectl get deployment k8s-cleaner-controller -n "$NAMESPACE" 2>/dev/null || true)
if [ -n "$EXISTING" ] && [ "$UPGRADE" = false ]; then
    echo "k8s-cleaner is already installed."
    echo "Use --upgrade to upgrade or --uninstall to remove first."
    exit 1
fi

# Download manifest
echo "Downloading manifest..."
MANIFEST_FILE=$(mktemp)
curl -sfL "$MANIFEST_URL" -o "$MANIFEST_FILE"

# Replace version in manifest
if [ "$VERSION" != "main" ]; then
    sed -i "s|image: docker.io/projectsveltos/k8s-cleaner:v[0-9.]*|image: docker.io/projectsveltos/k8s-cleaner:$VERSION|" "$MANIFEST_FILE"
fi

# Replace namespace
if [ "$NAMESPACE" != "projectsveltos" ]; then
    sed -i "s/namespace: projectsveltos/namespace: $NAMESPACE/g" "$MANIFEST_FILE"
fi

echo "Applying manifest..."
kubectl apply -f "$MANIFEST_FILE"

# Wait for deployment
echo ""
echo "Waiting for deployment to be ready..."
kubectl wait --for=condition=ready pod -l control-plane=k8s-cleaner \
    -n "$NAMESPACE" --timeout=120s 2>/dev/null || {
    echo "Warning: Timeout waiting for pod to be ready"
    echo "Checking pod status..."
    kubectl get pods -n "$NAMESPACE" -l control-plane=k8s-cleaner
}

rm -f "$MANIFEST_FILE"

echo ""
echo "========================================="
echo "k8s-cleaner installed successfully!"
echo "========================================="
echo ""
echo "Namespace: $NAMESPACE"
echo ""
echo "Useful commands:"
echo "  kubectl get pods -n $NAMESPACE"
echo "  kubectl get cleaner -A"
echo "  kubectl logs -n $NAMESPACE -l control-plane=k8s-cleaner"
