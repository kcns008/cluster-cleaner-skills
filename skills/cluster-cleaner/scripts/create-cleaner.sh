#!/bin/bash
set -e

NAMESPACE="${NAMESPACE:-projectsveltos}"
SCHEDULE="${SCHEDULE:-0 0 * * *}"
ACTION="${ACTION:-Scan}"
KIND="${KIND:-ConfigMap}"
GROUP="${GROUP:-}"
VERSION="${VERSION:-v1}"

usage() {
    cat << EOF
Generate k8s-cleaner Cleaner YAML from templates

Usage: $0 [OPTIONS]

OPTIONS:
    -k, --kind KIND              Resource kind (ConfigMap, Secret, Job, etc.)
    -g, --group GROUP            API group (apps, batch, etc.)
    -v, --version VERSION       API version (default: v1)
    -n, --namespace NAMESPACE   Target namespace (optional)
    -s, --schedule SCHEDULE     Cron schedule (default: "0 0 * * *")
    -a, --action ACTION         Action: Scan, Delete, Update (default: Scan)
    -l, --label KEY=VALUE        Label filter (can be repeated)
    -o, --output FILE            Output file (default: stdout)
    --lua LUA_FILE               Lua evaluation script file
    -h, --help                  Show this help

EXAMPLES:
    $0 -k ConfigMap -s "0 0 * * *" -a Delete
    $0 -k Job -g batch -a Delete
    $0 -k Secret -l environment=dev -l team=frontend
    $0 -k Pod --lua /path/to/lua.lua -o cleaner.yaml
EOF
    exit 1
}

LABELS=()
OUTPUT=""
LUA_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -k|--kind)
            KIND="$2"
            shift 2
            ;;
        -g|--group)
            GROUP="$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE_FILTER="$2"
            shift 2
            ;;
        -s|--schedule)
            SCHEDULE="$2"
            shift 2
            ;;
        -a|--action)
            ACTION="$2"
            shift 2
            ;;
        -l|--label)
            LABELS+=("$2")
            shift 2
            ;;
        -o|--output)
            OUTPUT="$2"
            shift 2
            ;;
        --lua)
            LUA_FILE="$2"
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

# Build label filters YAML
LABEL_FILTERS=""
if [ ${#LABELS[@]} -gt 0 ]; then
    LABEL_FILTERS=$'    labelFilters:\n'
    for label in "${LABELS[@]}"; do
        KEY="${label%%=*}"
        VALUE="${label##*=}"
        LABEL_FILTERS+="    - key: $KEY\n      operation: Equal\n      value: $VALUE\n"
    done
fi

# Determine API group
if [ -z "$GROUP" ]; then
    case "$KIND" in
        Pod|ConfigMap|Secret|Service|PersistentVolumeClaim|ServiceAccount)
            GROUP="\"\""
            ;;
        Deployment|StatefulSet|DaemonSet|ReplicaSet)
            GROUP="\"apps\""
            ;;
        Job|CronJob)
            GROUP="\"batch\""
            ;;
        Ingress)
            GROUP="\"networking.k8s.io\""
            ;;
        *)
            GROUP="\"\""
            ;;
    esac
else
    GROUP="\"$GROUP\""
fi

# Build namespace filter
NAMESPACE_FILTER_YAML=""
if [ -n "$NAMESPACE_FILTER" ]; then
    NAMESPACE_FILTER_YAML="      namespace: $NAMESPACE_FILTER"
fi

# Build Lua evaluation
LUA_EVALUATION=""
if [ -n "$LUA_FILE" ] && [ -f "$LUA_FILE" ]; then
    LUA_CONTENT=$(cat "$LUA_FILE")
    LUA_EVALUATION="      evaluate: |
$LUA_CONTENT"
elif [ -z "$LUA_EVALUATION" ]; then
    # Default Lua: simple matching based on age or status
    LUA_EVALUATION="      evaluate: |
        function evaluate()
          hs = {}
          hs.matching = false
          hs.message = \"Resource matches cleanup criteria\"
          return hs
        end"
fi

# Generate YAML
cat << EOF
apiVersion: apps.projectsveltos.io/v1alpha1
kind: Cleaner
metadata:
  name: cleanup-${KIND,,}
spec:
  schedule: "$SCHEDULE"
  action: $ACTION
  resourcePolicySet:
    resourceSelectors:
    - kind: $KIND
      group: $GROUP
      version: $VERSION
$NAMESPACE_FILTER_YAML
$LABEL_FILTERS$LUA_EVALUATION
EOF
