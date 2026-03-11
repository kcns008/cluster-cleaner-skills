#!/bin/bash

NAMESPACE="${NAMESPACE:-projectsveltos}"

usage() {
    cat << EOF
Get summary of k8s-cleaner Cleaner resources in the cluster

Usage: $0 [OPTIONS]

OPTIONS:
    -n, --namespace NAMESPACE    Namespace to query (default: projectsveltos)
    -o, --output FORMAT          Output format: table, yaml, json (default: table)
    -h, --help                   Show this help

EXAMPLES:
    $0                           # Show all Cleaners
    $0 -n myns                   # Custom namespace
    $0 -o yaml                   # Output as YAML
EOF
    exit 1
}

OUTPUT="table"

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT="$2"
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

echo "=== k8s-cleaner Summary ==="
echo "Namespace: $NAMESPACE"
echo ""

# Get all Cleaner resources
CLEANERS=$(kubectl get cleaner -n "$NAMESPACE" -o name 2>/dev/null)

if [ -z "$CLEANERS" ]; then
    echo "No Cleaner resources found in namespace: $NAMESPACE"
    exit 0
fi

case "$OUTPUT" in
    table)
        printf "%-30s %-15s %-15s %-20s\n" "NAME" "ACTION" "SCHEDULE" "RESOURCES"
        printf "%-30s %-15s %-15s %-20s\n" "----" "------" "--------" "---------"
        ;;
    yaml|json)
        kubectl get cleaner -n "$NAMESPACE" -o "$OUTPUT"
        exit 0
        ;;
esac

# Get details for each Cleaner
for cleaner in $CLEANERS; do
    NAME=$(kubectl get "$cleaner" -n "$NAMESPACE" -o jsonpath='{.metadata.name}')
    ACTION=$(kubectl get "$cleaner" -n "$NAMESPACE" -o jsonpath='{.spec.action}')
    SCHEDULE=$(kubectl get "$cleaner" -n "$NAMESPACE" -o jsonpath='{.spec.schedule}')
    
    # Get resource kinds
    KINDS=$(kubectl get "$cleaner" -n "$NAMESPACE" -o jsonpath='{range .spec.resourcePolicySet.resourceSelectors[*]}{.kind}{", "}{end}' | sed 's/, $//')
    
    printf "%-30s %-15s %-15s %-20s\n" "$NAME" "$ACTION" "$SCHEDULE" "$KINDS"
done

echo ""
echo "=== Additional Info ==="
echo "Total Cleaners: $(echo $CLEANERS | wc -w)"
echo ""
echo "View details: kubectl get cleaner <name> -n $NAMESPACE -o yaml"
echo "View logs: kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=k8s-cleaner"
