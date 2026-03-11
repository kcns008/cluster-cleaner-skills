---
name: cluster-cleaner
description: |
  Kubernetes resource cleanup and maintenance using k8s-cleaner. Use this skill when:
  (1) Cleaning up stale/orphaned/unused resources (ConfigMaps, Secrets, PVCs, Jobs, Pods)
  (2) Identifying unhealthy resources (outdated secrets, expired certificates)
  (3) Automated resource management with scheduling and Lua-based criteria
  (4) Setting up notifications for cleanup operations (Slack, Webex, Discord, Teams, SMTP)
  (5) Generating cleanup reports and validating cleaner configurations
  (6) Implementing time-based resource expiration and lifecycle management
metadata:
  author: cluster-cleaner-skills
  version: "1.0.0"
---

# Kubernetes Cleaner (k8s-cleaner)

AI agent skill for managing Kubernetes cluster hygiene using k8s-cleaner - a controller that identifies, removes, or updates stale/orphaned or unhealthy resources.

## Overview

k8s-cleaner is a Kubernetes controller that helps maintain clean and efficient clusters by:
- Identifying unused resources (ConfigMaps, Secrets, PVCs, Jobs, etc.)
- Detecting unhealthy resources (outdated secrets, expired certificates)
- Automating cleanup with flexible scheduling (Cron syntax)
- Providing notifications via multiple channels
- Supporting Lua-based selection criteria for complex logic

**Project**: https://github.com/gianlucam76/k8s-cleaner
**Documentation**: https://gianlucam76.github.io/k8s-cleaner/

---

## 1. INSTALLATION

### Option 1: kubectl (Recommended - No Helm Required)

Using the install script:
```bash
# Install latest version
bash skills/cluster-cleaner/scripts/install-cleaner.sh

# Install specific version
bash skills/cluster-cleaner/scripts/install-cleaner.sh -v v0.18.0

# Install in custom namespace
bash skills/cluster-cleaner.sh -n my-namespace

# Upgrade existing installation
bash skills/cluster-cleaner/scripts/install-cleaner.sh --upgrade

# Uninstall
bash skills/cluster-cleaner/scripts/install-cleaner.sh --uninstall
```

Or manually using kubectl:
```bash
# Apply the manifest directly
kubectl apply -f https://raw.githubusercontent.com/gianlucam76/k8s-cleaner/v0.19.1/manifest/manifest.yaml
```

### Option 2: Helm Installation

```bash
# Add the Sveltos Helm repository
helm repo add projectsveltos https://projectsveltos.github.io/helm-charts

# Update helm repos
helm repo update

# Install k8s-cleaner
helm install k8s-cleaner projectsveltos/k8s-cleaner \
  --namespace projectsveltos \
  --create-namespace
```

### Verify Installation

```bash
# Check if CRD is installed
kubectl get crd | grep cleaner

# Check pod status
kubectl get pods -n projectsveltos

# Check available Cleaner resources
kubectl get cleaner -A
```

---

## 2. CORE CONCEPTS

### Cleaner CRD Structure

```yaml
apiVersion: apps.projectsveltos.io/v1alpha1
kind: Cleaner
metadata:
  name: <cleaner-name>
spec:
  schedule: "<cron-expression>"      # When to run (Cron syntax)
  action: <Scan|Delete|Update>      # Action to take
  dryRun: <true|false>              # Preview without changes
  resourcePolicySet:
    resourceSelectors:
    - kind: <ResourceKind>           # Pod, ConfigMap, Secret, etc.
      group: <api-group>            # "" for core, "apps" for apps/v1
      version: <api-version>         # v1, v1alpha1, etc.
      namespace: <namespace>         # Specific namespace (optional)
      labelFilters:                 # Label-based filtering
      - key: <label-key>
        operation: <Equal|NotEqual|Exists|NotExists|In|NotIn>
        value: <label-value>
      evaluate: |                   # Lua-based selection
        function evaluate()
          -- Lua logic here
        end
  notifications:                    # Notification channels
  - name: <notification-name>
    type: <Slack|Webex|Discord|Teams|Telegram|SMTP|Event>
    notificationRef:
      apiVersion: v1
      kind: Secret
      name: <secret-name>
      namespace: <namespace>
```

### Action Types

| Action | Description |
|--------|-------------|
| `Scan` | Dry-run mode - identify matching resources without deleting/updating |
| `Delete` | Remove matching resources |
| `Update` | Modify matching resources (add/remove labels, annotations) |

### Schedule Formats

k8s-cleaner supports standard Cron and descriptors:

```yaml
# Standard crontab
schedule: "* * * * *"        # Every minute
schedule: "0 * * * *"        # Every hour
schedule: "0 0 * * *"        # Daily at midnight
schedule: "0 0 * * 0"        # Weekly on Sunday

# Descriptors
schedule: "@every 1h30m"     # Every 1 hour 30 minutes
schedule: "@midnight"        # Daily at midnight
schedule: "@hourly"          # Every hour
```

---

## 3. LABEL FILTERS

Label filters refine resource selection based on Kubernetes labels.

### Filter Operations

| Operation | Description | Example |
|-----------|-------------|---------|
| `Equal` | Label value equals | `environment=production` |
| `Different` | Label value differs | `environment!=production` |
| `Exists` | Label key exists | `tier` (any value) |
| `NotExists` | Label key missing | `!tier` |
| `In` | Label value in list | `tier in (frontend,backend)` |
| `NotIn` | Label value not in list | `tier notin (dev,test)` |

### Example

```yaml
resourceSelectors:
- kind: Deployment
  group: apps
  version: v1
  labelFilters:
  - key: environment
    operation: Equal
    value: dev
  - key: team
    operation: Exists
```

---

## 4. LUA-BASED SELECTION

The `evaluate` function in Lua allows complex selection logic.

### Lua Function Structure

```lua
function evaluate()
  local hs = {}
  hs.matching = false  -- Does resource match?
  hs.message = ""      -- Optional message
  hs.resources = {}    -- For aggregated selection

  -- Your logic here
  if <condition> then
    hs.matching = true
  end

  return hs
end
```

### Available Lua Helpers

| Function | Description |
|----------|-------------|
| `obj` | The Kubernetes resource being evaluated |
| `obj.metadata` | Resource metadata (name, namespace, labels, annotations) |
| `obj.spec` | Resource spec |
| `obj.status` | Resource status |
| `resources` | All resources fetched (for aggregated selection) |

### Example: Delete completed Jobs

```yaml
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
action: Delete
```

### Example: Find pods with expired certificates

```yaml
resourceSelectors:
- kind: Pod
  group: ""
  version: v1
  evaluate: |
    function evaluate()
      hs = {}
      hs.matching = false
      
      if obj.spec ~= nil and obj.spec.containers ~= nil then
        for _, container in ipairs(obj.spec.containers) do
          if container.env ~= nil then
            for _, env in ipairs(container.env) do
              if env.valueFrom ~= nil and env.valueFrom.secretRef ~= nil then
                hs.matching = true
                break
              end
            end
          end
        end
      end
      
      return hs
    end
```

---

## 5. COMMON USE CASES

### 5.1 Unused ConfigMaps

Delete ConfigMaps not used by any Pod:

```yaml
apiVersion: apps.projectsveltos.io/v1alpha1
kind: Cleaner
metadata:
  name: unused-configmaps
spec:
  schedule: "0 0 * * *"  # Daily at midnight
  action: Delete
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
        local unusedConfigMaps = {}

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
```

### 5.2 Unused Secrets

Delete unused Secrets:

```yaml
apiVersion: apps.projectsveltos.io/v1alpha1
kind: Cleaner
metadata:
  name: unused-secrets
spec:
  schedule: "0 0 * * *"
  action: Delete
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
```

### 5.3 Completed Jobs

Delete finished Jobs:

```yaml
apiVersion: apps.projectsveltos.io/v1alpha1
kind: Cleaner
metadata:
  name: completed-jobs
spec:
  schedule: "@every 1h"
  action: Delete
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
```

### 5.4 Terminating PVCs

Delete stuck PersistentVolumeClaims:

```yaml
apiVersion: apps.projectsveltos.io/v1alpha1
kind: Cleaner
metadata:
  name: stuck-pvcs
spec:
  schedule: "0 * * * *"
  action: Delete
  resourcePolicySet:
    resourceSelectors:
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
```

### 5.5 Time-Based Cleanup (TTL)

Delete resources with expiration annotation:

```yaml
apiVersion: apps.projectsveltos.io/v1alpha1
kind: Cleaner
metadata:
  name: ttl-resources
spec:
  schedule: "0 * * * *"
  action: Delete
  resourcePolicySet:
    resourceSelectors:
    - kind: ConfigMap
      group: ""
      version: v1
      evaluate: |
        function evaluate()
          hs = {}
          hs.matching = false
          
          local expiration = obj.metadata.annotations["cleanup.kubernetes.io/expire-after"]
          if expiration ~= nil then
            local expireTime = os.date("!%Y-%m-%dT%H:%M:%SZ", os.time() - tonumber(expiration))
            local creationTime = obj.metadata.creationTimestamp
            
            if expireTime > creationTime then
              hs.matching = true
            end
          end
          
          return hs
        end
```

---

## 6. NOTIFICATIONS

Configure notifications to receive alerts about cleanup operations.

### Slack

```bash
# Create secret
kubectl create secret generic slack \
  --from-literal=SLACK_TOKEN=<TOKEN> \
  --from-literal=SLACK_CHANNEL_ID=<CHANNEL_ID>
```

```yaml
notifications:
- name: slack
  type: Slack
  notificationRef:
    apiVersion: v1
    kind: Secret
    name: slack
    namespace: default
```

### Webex

```bash
kubectl create secret generic webex \
  --from-literal=WEBEX_TOKEN=<TOKEN> \
  --from-literal=WEBEX_ROOM_ID=<ROOM_ID>
```

### Discord

```bash
kubectl create secret generic discord \
  --from-literal=DISCORD_TOKEN=<TOKEN> \
  --from-literal=DISCORD_CHANNEL_ID=<CHANNEL_ID>
```

### Teams

```bash
kubectl create secret generic teams \
  --from-literal=TEAMS_WEBHOOK_URL=<WEBHOOK_URL>
```

### SMTP (Email)

```bash
kubectl create secret generic smtp \
  --from-literal=SMTP_RECIPIENTS=email@example.com \
  --from-literal=SMTP_SENDER=sender@example.com \
  --from-literal=SMTP_HOST=smtp.example.com \
  --from-literal=SMTP_PORT=587
```

### Kubernetes Events

```yaml
notifications:
- name: events
  type: Event
```

---

## 7. DRY RUN / PREVIEW

Always test Cleaner configurations with Dry Run before production:

```yaml
apiVersion: apps.projectsveltos.io/v1alpha1
kind: Cleaner
metadata:
  name: dry-run-example
spec:
  schedule: "0 * * * *"
  action: Scan  # Changed from Delete to Scan
  resourcePolicySet:
    resourceSelectors:
    - kind: ConfigMap
      group: ""
      version: v1
      namespace: test
```

After applying, check logs for matching resources:

```bash
kubectl logs -n projectsveltos -l app=k8s-cleaner | grep "resource is a match"
```

Or enable reports (see next section).

---

## 8. REPORTS

Generate reports of cleaned resources:

```yaml
spec:
  reports:
    destination:
      storage:
        secretRef:
          name: <s3-or-gcs-secret>
          namespace: projectsveltos
        prefix: "cleaner-reports"
```

---

## 9. UPDATE RESOURCES

Cleaner can also UPDATE matching resources (not just delete):

```yaml
apiVersion: apps.projectsveltos.io/v1alpha1
kind: Cleaner
metadata:
  name: add-cleanup-annotation
spec:
  schedule: "0 0 * * *"
  action: Update
  resourcePolicySet:
    resourceSelectors:
    - kind: ConfigMap
      group: ""
      version: v1
      namespace: old-apps
  postActions:
  - patch: |
      metadata:
        annotations:
          cleanup.kubernetes.io/checked: "true"
```

---

## 10. VALIDATE CLEANER CONFIGURATION

Validate your Cleaner configuration against test resources:

```bash
# Clone the repository
git clone https://github.com/gianlucam76/k8s-cleaner.git
cd k8s-cleaner

# Run unit tests with your config
make ut
```

See: https://github.com/gianlucam76/k8s-cleaner/blob/main/internal/controller/executor/validate_transform/README.md

---

## Helper Scripts

This skill includes automation scripts in the `scripts/` directory:

| Script | Purpose |
|--------|---------|
| `install-cleaner.sh` | Install/upgrade/uninstall k8s-cleaner using kubectl |
| `create-cleaner.sh` | Generate Cleaner YAML from templates |
| `deploy-example.sh` | Deploy example Cleaner configurations |
| `cleaner-logs.sh` | View logs, status, and debug Cleaner |
| `validate-lua.sh` | Validate Lua evaluation scripts |
| `cleanup-summary.sh` | Get summary of Cleaner resources |

### Usage

```bash
# Install k8s-cleaner (no Helm required!)
bash skills/cluster-cleaner/scripts/install-cleaner.sh

# Install specific version
bash skills/cluster-cleaner/scripts/install-cleaner.sh -v v0.18.0

# Upgrade existing installation
bash skills/cluster-cleaner/scripts/install-cleaner.sh --upgrade

# Create a Cleaner for unused ConfigMaps
bash skills/cluster-cleaner/scripts/create-cleaner.sh configmap --schedule "0 0 * * *" --action Delete

# Deploy example configurations
bash skills/cluster-cleaner/scripts/deploy-example.sh -e configmap
bash skills/cluster-cleaner/scripts/deploy-example.sh -e job -a Delete

# View logs and status
bash skills/cluster-cleaner/scripts/cleaner-logs.sh -f
bash skills/cluster-cleaner/scripts/cleaner-logs.sh -c

# Validate Lua script
bash skills/cluster-cleaner/scripts/validate-lua.sh /path/to/lua-script.lua
```

---

## Quick Reference

### Common Resource Kinds

| Kind | Group | Version |
|------|-------|---------|
| Pod | "" | v1 |
| ConfigMap | "" | v1 |
| Secret | "" | v1 |
| PersistentVolumeClaim | "" | v1 |
| Job | batch | v1 |
| Deployment | apps | v1 |
| StatefulSet | apps | v1 |
| Service | "" | v1 |
| Ingress | networking.k8s.io | v1 |

### Cron Examples

| Schedule | Meaning |
|----------|---------|
| `* * * * *` | Every minute |
| `0 * * * *` | Every hour |
| `0 0 * * *` | Daily at midnight |
| `0 0 * * 0` | Weekly (Sunday) |
| `0 0 1 * *` | Monthly (1st) |
| `@every 1h30m` | Every 1.5 hours |
