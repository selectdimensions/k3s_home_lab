# K3s Upgrade Runbook

## Overview

This runbook describes the process for upgrading K3s on the cluster nodes, including version upgrades and handling version skew issues.

## Prerequisites

- SSH access to all cluster nodes
- kubectl configured and working
- Backup of cluster resources (see [Backup Procedures](#backup-before-upgrade))

---

## Backup Before Upgrade

Always create a backup before any upgrade:

```powershell
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
mkdir "backups\pre-upgrade-$timestamp"
kubectl get all -A -o yaml > "backups\pre-upgrade-$timestamp\all-resources.yaml"
kubectl get pv,pvc -A -o yaml > "backups\pre-upgrade-$timestamp\persistent-volumes.yaml"
kubectl get configmaps -A -o yaml > "backups\pre-upgrade-$timestamp\configmaps.yaml"
kubectl get secrets -A -o yaml > "backups\pre-upgrade-$timestamp\secrets.yaml"
kubectl get nodes -o yaml > "backups\pre-upgrade-$timestamp\nodes.yaml"
```

---

## Standard K3s Upgrade

### Option A: Automated Upgrade Script

```powershell
# Run the automated upgrade script
.\Upgrade-K3sMaster.ps1 -BackupFirst $true

# This will:
# 1. Create full cluster backup
# 2. Upgrade master to target version
# 3. Restart workers to reconnect
# 4. Verify the upgrade
```

**Time**: ~30 minutes including validation

### Option B: Manual Upgrade Steps

#### Step 1: Upgrade Master Node (10 minutes)

```bash
# SSH to master
ssh hezekiah@192.168.0.120

# Stop k3s
sudo systemctl stop k3s

# Upgrade to target version (example: v1.32.5+k3s1)
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.32.5+k3s1 sh -s - server \
  --disable traefik \
  --disable servicelb \
  --write-kubeconfig-mode 644

# Restart k3s
sudo systemctl restart k3s

# Verify
k3s --version
sudo systemctl status k3s
```

#### Step 2: Restart Worker Agents (5 minutes per worker)

```bash
# On each worker node
ssh hezekiah@192.168.0.121  # pi-worker-1
sudo systemctl restart k3s-agent
sudo systemctl status k3s-agent

ssh hezekiah@192.168.0.122  # pi-worker-2
sudo systemctl restart k3s-agent
sudo systemctl status k3s-agent

ssh hezekiah@192.168.0.123  # pi-worker-3
sudo systemctl restart k3s-agent
sudo systemctl status k3s-agent
```

#### Step 3: Verify Upgrade (5 minutes)

```powershell
# Check all nodes have same version
kubectl get nodes -o custom-columns=NAME:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion

# Wait for pods to stabilize
Start-Sleep -Seconds 30
kubectl get pods -A -o wide

# Check for any errors
kubectl get events -A --sort-by='.lastTimestamp' | Select-Object -Last 20
```

---

## Version Skew Resolution

### Problem: Version Mismatch Between Master and Workers

**Symptoms:**
- Workers show "Ready" but pods fail with `CreateContainerConfigError`
- Error: "services have not yet been read at least once, cannot construct envvars"
- All pods running only on master node

**Kubernetes Version Skew Policy:**
- kubelet can be at most 2 minor versions older than kube-apiserver
- kubelet **cannot** be newer than kube-apiserver

### Diagnosis

```powershell
# Check node versions
kubectl get nodes -o wide

# Check for version-related errors
kubectl get events -A --field-selector reason=Failed | Select-Object -Last 10

# Check pod distribution
kubectl get pods -A -o wide | Group-Object { ($_ -split '\s+')[7] }
```

### Resolution: Upgrade Master to Match Workers

Follow the [Standard K3s Upgrade](#standard-k3s-upgrade) procedure above.

### Alternative: Downgrade Workers to Match Master

```bash
# On each worker
ssh hezekiah@192.168.0.121

# Stop agent
sudo systemctl stop k3s-agent

# Reinstall with matching version
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION=v1.28.4+k3s1 \
  K3S_URL=https://192.168.0.120:6443 \
  K3S_TOKEN=$(cat /var/lib/rancher/k3s/agent/node-token) \
  sh -s - agent

# Restart
sudo systemctl restart k3s-agent
```

---

## Workload Distribution After Upgrade

Optionally redistribute workloads across all nodes:

```powershell
# Drain master to force pod rescheduling
kubectl drain pi-master --ignore-daemonsets --delete-emptydir-data

# Watch pods move to workers
kubectl get pods -A -o wide --watch

# Uncordon master when satisfied
kubectl uncordon pi-master
```

---

## Troubleshooting

### SSH Connection Failed

```powershell
# Configure SSH key
ssh-copy-id hezekiah@192.168.0.120

# Test connection
ssh hezekiah@192.168.0.120 "echo connected"
```

### Master Upgrade Failed

```bash
# Check logs
sudo journalctl -u k3s -xe --no-pager | tail -100

# Kill any stuck processes
sudo /usr/local/bin/k3s-killall.sh

# Retry installation
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.32.5+k3s1 sh -s - server \
  --disable traefik --disable servicelb --write-kubeconfig-mode 644
```

### Pods Still Not Scheduling on Workers

```powershell
# Check node status
kubectl describe node pi-worker-1

# Check for taints
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.taints}{"\n"}{end}'

# Remove NoSchedule taint if present
kubectl taint nodes pi-worker-1 node.kubernetes.io/unschedulable:NoSchedule-
```

### Services Not Accessible After Upgrade

```powershell
# Check pod logs
kubectl logs -n data-engineering deployment/nifi --tail=50
kubectl logs -n monitoring deployment/grafana --tail=50

# Restart problematic deployments
kubectl -n data-engineering rollout restart deployment/nifi
kubectl -n monitoring rollout restart deployment/grafana
```

---

## Validation Checklist

After upgrade, verify:

- [ ] All nodes show same K3s version
- [ ] All nodes in Ready status
- [ ] Pods distributed across nodes (not just master)
- [ ] No CreateContainerConfigError events
- [ ] Services accessible (NiFi, Grafana, etc.)
- [ ] Monitoring collecting metrics

```powershell
# Quick validation script
kubectl get nodes -o wide
kubectl get pods -A | Where-Object { $_ -notmatch "Running|Completed" }
kubectl get events -A --field-selector type=Warning | Select-Object -Last 5
```

---

## Time Estimates

| Phase | Duration | Risk Level |
|-------|----------|------------|
| Backup | 5 min | Low |
| Master Upgrade | 10 min | Medium |
| Worker Restart (x3) | 15 min | Low |
| Verification | 5 min | Low |
| Workload Distribution | 10 min | Low |
| **Total** | **45 min** | **Medium** |

---

## Prevention Best Practices

1. **Version Pinning**: Always specify exact K3s version in deployment scripts
2. **Sequential Upgrades**: Upgrade master first, then workers
3. **Validation Scripts**: Add version checks to `.\Make.ps1 validate`
4. **Documentation**: Keep cluster version documented in README
5. **Test First**: Test upgrades in dev environment before production

---

## Related Documentation

- [Node Failure Recovery](./node-failure-recovery.md)
- [K3s Official Upgrade Docs](https://docs.k3s.io/upgrades)
- [Kubernetes Version Skew Policy](https://kubernetes.io/releases/version-skew-policy/)
