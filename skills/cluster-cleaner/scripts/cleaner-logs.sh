#!/bin/bash

NAMESPACE="${NAMESPACE:-projectsveltos}"
SINCE="${SINCE:-5m}"

usage() {
    cat << EOF
View k8s-cleaner logs and status

Usage: $0 [OPTIONS]

OPTIONS:
    -n, --namespace NAMESPACE    Namespace (default: projectsveltos)
    -f, --follow                Follow logs (tail -f)
    -s, --since DURATION        Show logs since (default: 5m)
    -l, --limit LIMIT           Limit number of log lines
    -p, --pods                  List pods only
    -c, --cleaners              List Cleaner resources
    -r, --reports               List Report resources
    -d, --describe CLEANER      Describe a Cleaner resource
    -h, --help                  Show this help

EXAMPLES:
    $0 -f                       # Follow logs
    $0 -p                       # List pods
    $0 -c                       # List Cleaner resources
    $0 -d cleanup-jobs          # Describe specific Cleaner
    $0 -l 100                   # Last 100 lines
EOF
    exit 1
}

FOLLOW=false
LIMIT=""
DESCRIBE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -f|--follow)
            FOLLOW=true
            shift
            ;;
        -s|--since)
            SINCE="$2"
            shift 2
            ;;
        -l|--limit)
            LIMIT="$2"
            shift 2
            ;;
        -p|--pods)
            kubectl get pods -n "$NAMESPACE" -l control-plane=k8s-cleaner
            exit 0
            ;;
        -c|--cleaners)
            kubectl get cleaner -A
            exit 0
            ;;
        -r|--reports)
            kubectl get report -A
            exit 0
            ;;
        -d|--describe)
            DESCRIBE="$2"
            shift 2
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

if [ -n "$DESCRIBE" ]; then
    kubectl describe cleaner "$DESCRIBE" -n "$NAMESPACE"
    exit 0
fi

# Build kubectl logs command
CMD="kubectl logs -n $NAMESPACE -l control-plane=k8s-cleaner --since=$SINCE"

if [ "$FOLLOW" = true ]; then
    CMD="$CMD -f"
fi

if [ -n "$LIMIT" ]; then
    CMD="$CMD --tail=$LIMIT"
fi

echo "Namespace: $NAMESPACE"
echo "Command: $CMD"
echo ""

# Check if cleaner is running
READY=$(kubectl get pods -n "$NAMESPACE" -l control-plane=k8s-cleaner -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
echo "Controller Status: $READY"
echo ""

# Show recent cleaners
echo "Recent Cleaner resources:"
kubectl get cleaner -A --sort-by='.metadata.creationTimestamp' 2>/dev/null | tail -5
echo ""

# Show logs
echo "Logs:"
eval "$CMD"
