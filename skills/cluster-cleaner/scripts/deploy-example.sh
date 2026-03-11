#!/bin/bash
set -e

NAMESPACE="${NAMESPACE:-projectsveltos}"

usage() {
    cat << EOF
Deploy example k8s-cleaner configurations

Usage: $0 [OPTIONS]

OPTIONS:
    -n, --namespace NAMESPACE    Target namespace for resources (default: projectsveltos)
    -a, --action ACTION          Action: Scan, Delete (default: Scan)
    -s, --schedule SCHEDULE     Cron schedule (default: "0 0 * * *")
    -l, --list                  List available examples
    -e, --example EXAMPLE       Example to deploy: configmap, secret, job, pvc, all
    -h, --help                  Show this help

EXAMPLES:
    $0 -e configmap                    # Deploy unused ConfigMap cleaner
    $0 -e job -a Delete                # Deploy completed Job cleaner
    $0 -e all                          # Deploy all examples
    $0 -l                              # List available examples
EOF
    exit 1
}

EXAMPLES_DIR="$(dirname "$0")/../examples"

list_examples() {
    echo "Available examples:"
    echo ""
    echo "  configmap    - Remove unused ConfigMaps"
    echo "  secret       - Remove unused Secrets"
    echo "  job          - Remove completed Jobs"
    echo "  pvc          - Remove terminating PVCs"
    echo "  all          - Deploy all examples"
}

deploy_example() {
    local example="$1"
    local action="${2:-$ACTION}"
    local schedule="${3:-$SCHEDULE}"
    
    case "$example" in
        configmap)
            cat << 'EOF'
apiVersion: apps.projectsveltos.io/v1alpha1
kind: Cleaner
metadata:
  name: cleanup-unused-configmaps
spec:
  schedule: "0 0 * * *"
  action: Scan
  resourcePolicySet:
    resourceSelectors:
    - kind: Pod
      group: ""
      version: v1
    - kind: ConfigMap
      group: ""
      version: v1
    aggregatedSelection: |
      function skipNamespace(namespace)
        return string.match(namespace, '^kube')
      end

      function getKey(namespace, name)
        return namespace .. ":" .. name
      end

      function evaluate()
        local hs = {}
        local pods = {}
        local configMaps = {}

        for _, resource in ipairs(resources) do
          local kind = resource.kind
          if kind == "ConfigMap" and not skipNamespace(resource.metadata.namespace) then
            table.insert(configMaps, resource)
          elseif kind == "Pod" then
            table.insert(pods, resource)
          end
        end

        local podConfigMaps = {}
        for _, pod in ipairs(pods) do
          if pod.spec.containers ~= nil then
            for _, container in ipairs(pod.spec.containers) do
              if container.envFrom ~= nil then
                for _, envFrom in ipairs(container.envFrom) do
                  if envFrom.configMapRef ~= nil then
                    key = getKey(pod.metadata.namespace, envFrom.configMapRef.name)
                    podConfigMaps[key] = true
                  end
                end
              end
            end
          end
        end

        local unusedConfigMaps = {}
        for _, configMap in ipairs(configMaps) do
          key = getKey(configMap.metadata.namespace, configMap.metadata.name)
          if not podConfigMaps[key] then
            table.insert(unusedConfigMaps, configMap)
          end
        end

        if #unusedConfigMaps > 0 then
          hs.resources = unusedConfigMaps
        end
        return hs
      end
EOF
            ;;
        secret)
            cat << 'EOF'
apiVersion: apps.projectsveltos.io/v1alpha1
kind: Cleaner
metadata:
  name: cleanup-unused-secrets
spec:
  schedule: "0 0 * * *"
  action: Scan
  resourcePolicySet:
    resourceSelectors:
    - kind: Pod
      group: ""
      version: v1
    - kind: Secret
      group: ""
      version: v1
    aggregatedSelection: |
      function evaluate()
        hs = {}
        pods = {}
        secrets = {}
        
        for _, resource in ipairs(resources) do
          if resource.kind == "Secret" then
            table.insert(secrets, resource)
          elseif resource.kind == "Pod" then
            table.insert(pods, resource)
          end
        end
        
        usedSecrets = {}
        for _, pod in ipairs(pods) do
          if pod.spec ~= nil then
            if pod.spec.imagePullSecrets ~= nil then
              for _, secret in ipairs(pod.spec.imagePullSecrets) do
                usedSecrets[pod.metadata.namespace .. ":" .. secret.name] = true
              end
            end
          end
        end
        
        unusedSecrets = {}
        for _, secret in ipairs(secrets) do
          key = secret.metadata.namespace .. ":" .. secret.metadata.name
          if not usedSecrets[key] then
            table.insert(unusedSecrets, secret)
          end
        end
        
        if #unusedSecrets > 0 then
          hs.resources = unusedSecrets
        end
        return hs
      end
EOF
            ;;
        job)
            cat << EOF
apiVersion: apps.projectsveltos.io/v1alpha1
kind: Cleaner
metadata:
  name: cleanup-completed-jobs
spec:
  schedule: "@every 1h"
  action: $action
  resourcePolicySet:
    resourceSelectors:
    - kind: Job
      group: batch
      version: v1
      evaluate: |
        function evaluate()
          hs = {}
          hs.matching = false
          if obj.status ~= nil then
            if obj.status.completionTime ~= nil and obj.status.succeeded > 0 then
              hs.matching = true
            end
          end
          return hs
        end
EOF
            ;;
        pvc)
            cat << 'EOF'
apiVersion: apps.projectsveltos.io/v1alpha1
kind: Cleaner
metadata:
  name: cleanup-terminating-pvcs
spec:
  schedule: "0 * * * *"
  action: Scan
:
    resourceSelectors  resourcePolicySet:
    - kind: PersistentVolumeClaim
      group: ""
      version: v1
      evaluate: |
        function evaluate()
          hs = {}
          hs.matching = false
          if obj.status ~= nil and obj.status.phase ~= nil then
            if obj.status.phase == "Terminating" then
              hs.matching = true
            end
          end
          return hs
        end
EOF
            ;;
        *)
            echo "Unknown example: $example"
            exit 1
            ;;
    esac
}

ACTION="Scan"
SCHEDULE="0 0 * * *"
EXAMPLE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -a|--action)
            ACTION="$2"
            shift 2
            ;;
        -s|--schedule)
            SCHEDULE="$2"
            shift 2
            ;;
        -l|--list)
            list_examples
            exit 0
            ;;
        -e|--example)
            EXAMPLE="$2"
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

if [ -z "$EXAMPLE" ]; then
    usage
fi

if [ "$EXAMPLE" = "all" ]; then
    echo "Deploying all examples..."
    echo ""
    
    for ex in configmap secret job pvc; do
        echo "--- Deploying $ex ---"
        deploy_example "$ex" "Scan" "$SCHEDULE"
        echo ""
    done
else
    deploy_example "$EXAMPLE" "$ACTION" "$SCHEDULE"
fi
