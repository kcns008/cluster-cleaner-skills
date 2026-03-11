# Cluster Cleaner Skills

AI agent skill for Kubernetes resource cleanup and maintenance using [k8s-cleaner](https://github.com/gianlucam76/k8s-cleaner).

## Overview

This skill provides AI agents with comprehensive capabilities to manage Kubernetes cluster hygiene by:

- **Identifying unused resources**: ConfigMaps, Secrets, PVCs, Jobs, Pods, etc.
- **Detecting unhealthy resources**: Outdated secrets, expired certificates
- **Automated cleanup**: Flexible scheduling with Cron syntax
- **Lua-based selection**: Complex resource selection logic
- **Notifications**: Slack, Webex, Discord, Teams, SMTP, Kubernetes Events

## Usage with AI Agents

This skill follows the [Agent Skills](https://agentskills.io/) format. Install using:

```bash
npx skills add https://github.com/kcns008/cluster-cleaner-skills --skill cluster-cleaner
```

Or reference directly in your agent configuration.

## Quick Start

### Installation

```bash
# Install k8s-cleaner (no Helm required!)
bash skills/cluster-cleaner/scripts/install-cleaner.sh
```

### Create a Cleaner

```bash
# Create a Cleaner for unused ConfigMaps
bash skills/cluster-cleaner/scripts/create-cleaner.sh \
    -k ConfigMap \
    -s "0 0 * * *" \
    -a Delete

# Create a Cleaner for completed Jobs
bash skills/cluster-cleaner/scripts/create-cleaner.sh \
    -k Job \
    -g batch \
    -a Delete
```

### Deploy Example Configurations

```bash
# Deploy example cleaners
bash skills/cluster-cleaner/scripts/deploy-example.sh -e configmap
bash skills/cluster-cleaner/scripts/deploy-example.sh -e job -a Delete
```

## Skill Structure

```
skills/cluster-cleaner/
├── SKILL.md              # Main skill documentation
└── scripts/
    ├── install-cleaner.sh    # Install/upgrade/uninstall k8s-cleaner
    ├── create-cleaner.sh    # Generate Cleaner YAML
    ├── deploy-example.sh    # Deploy example configurations
    ├── cleaner-logs.sh      # View logs and status
    ├── validate-lua.sh      # Validate Lua scripts
    └── cleanup-summary.sh   # List Cleaner resources
```

## Features

1. **Installation**: kubectl-based installation (no Helm required)
2. **Core Concepts**: Cleaner CRD, schedule, label filters, Lua evaluation
3. **Common Use Cases**: 
   - Unused ConfigMaps/Secrets
   - Completed Jobs
   - Terminating PVCs
   - Time-based cleanup
4. **Notifications**: Multiple notification channels
5. **Dry Run**: Preview before actual cleanup
6. **Reports**: Generate cleanup reports

## Documentation

- [k8s-cleaner GitHub](https://github.com/gianlucam76/k8s-cleaner)
- [k8s-cleaner Docs](https://gianlucam76.github.io/k8s-cleaner/)

## Related Skills

- [cluster-skills](https://github.com/kcns008/cluster-skills) - Kubernetes operations skills
- [cluster-agent-swarm](https://github.com/kcns008/cluster-agent-swarm-skills) - Platform engineering swarm
