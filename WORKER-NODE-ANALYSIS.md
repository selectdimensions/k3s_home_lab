# Worker Node Deployment Analysis and Resolution Plan

**Date**: 2025-11-28
**Status**: CRITICAL - Version Skew Detected

## Executive Summary

The worker nodes (pi-worker-1, pi-worker-2) are showing as "Ready" in the cluster but are **not functional** due to a critical version skew issue. All workloads are concentrated on the master node.

## Current State

### Node Status
```
NAME          STATUS   VERSION        AGE
pi-master     Ready    v1.28.4+k3s1   165d
pi-worker-1   Ready    v1.32.5+k3s1   162d
pi-worker-2   Ready    v1.32.5+k3s1   162d
```

### Critical Issues Identified

#### 1. **VERSION SKEW - ROOT CAUSE** ⚠️
- **Master**: k3s v1.28.4 (released June 2023)
- **Workers**: k3s v1.32.5 (released December 2024)
- **Gap**: 4 minor versions (UNSUPPORTED)

**Kubernetes Version Skew Policy**:
- kubelet can be at most 2 minor versions older than kube-apiserver
- kubelet **cannot** be newer than kube-apiserver
- Current configuration violates this policy

**Impact**:
- Pods on workers fail with: "services have not yet been read at least once, cannot construct envvars"
- Worker kubelets cannot properly communicate with older API server
- New API features on workers not supported by older control plane

#### 2. **Pod Distribution Issue**
All application pods running on master only:
```
NAMESPACE          POD                    NODE
monitoring         alertmanager           pi-master
monitoring         prometheus             pi-master
monitoring         grafana                pi-master
kube-system        coredns                pi-master
kube-system        local-path             pi-master
kube-system        metrics-server         pi-master
data-engineering   minio                  pi-master
data-engineering   postgresql             pi-master
data-engineering   trino                  pi-master
data-engineering   nifi                   pi-master
```

**Worker Pods Failing**:
```
monitoring         node-exporter-f75w7    pi-worker-1   CreateContainerConfigError
monitoring         node-exporter-tq9d2    pi-worker-2   CreateContainerConfigError
```

#### 3. **DNS Configuration Warning**
```
Warning: Nameserver limits were exceeded, some nameservers have been omitted
Applied: 8.8.8.8 1.1.1.1 192.168.0.1
```

## Root Cause Analysis

The version skew is preventing proper pod scheduling and execution on worker nodes because:

1. **API Compatibility**: v1.32 kubelet expects API endpoints and behaviors that don't exist in v1.28 API server
2. **Service Discovery**: Worker kubelets cannot properly read service definitions from the older API server
3. **Container Runtime**: containerd versions differ (1.7.7 vs 2.0.5), causing additional compatibility issues

## Resolution Options

### **Option 1: Upgrade Master to v1.32.5** (RECOMMENDED)
**Pros**:
- Matches worker versions
- Gets latest features and security patches
- Forward-compatible approach

**Cons**:
- Requires master node upgrade (potential downtime)
- Need to backup cluster state first
- Manifest compatibility needs verification

**Steps**:
```powershell
# 1. Backup cluster
kubectl get all -A -o yaml > cluster-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').yaml

# 2. Drain master (optional, for safety)
kubectl drain pi-master --ignore-daemonsets --delete-emptydir-data

# 3. SSH to master and upgrade
ssh hezekiah@192.168.0.120
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.32.5+k3s1 sh -s - server \
  --disable traefik --disable servicelb --write-kubeconfig-mode 644

# 4. Restart master
sudo systemctl restart k3s

# 5. Verify
kubectl version
kubectl get nodes
```

### **Option 2: Downgrade Workers to v1.28.4**
**Pros**:
- Preserves master configuration
- Less risky than master upgrade

**Cons**:
- Running older, potentially vulnerable version
- Need to downgrade each worker
- Loses newer features

**Steps**:
```powershell
# For each worker node
ssh hezekiah@192.168.0.121
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.28.4+k3s1 sh -s - agent \
  --server https://192.168.0.120:6443 \
  --token <K3S_TOKEN>
```

### **Option 3: Fresh Cluster Deployment**
**Pros**:
- Clean slate with consistent versions
- Opportunity to fix configuration issues
- Can use Make.ps1 automation

**Cons**:
- Most disruptive
- Requires data migration
- Longer implementation time

**Steps**:
```powershell
# Use Make.ps1 to redeploy
.\Make.ps1 destroy -Environment dev
.\Make.ps1 init -Environment dev
.\Make.ps1 apply -Environment dev
.\Make.ps1 puppet-deploy -Targets "all" -Environment "dev"
```

## Immediate Workaround

While planning the proper fix, you can:

1. **Accept master-only workloads** temporarily
2. **Remove worker node selectors** to allow master scheduling
3. **Monitor master resources** closely

```powershell
# Check master resource usage
kubectl top node pi-master

# View events for issues
kubectl get events -A --sort-by='.lastTimestamp' | Select-Object -Last 20
```

## Recommended Action Plan

### Phase 1: Preparation (30 minutes)
1. ✅ Document current state (THIS DOCUMENT)
2. ⬜ Backup all cluster resources
3. ⬜ Backup persistent volumes
4. ⬜ Document current configurations
5. ⬜ Test access to all nodes

### Phase 2: Master Upgrade (45 minutes)
1. ⬜ Verify master backups
2. ⬜ Upgrade master to v1.32.5+k3s1
3. ⬜ Verify master node health
4. ⬜ Check API server accessibility
5. ⬜ Verify etcd/datastore integrity

### Phase 3: Worker Reconnection (30 minutes)
1. ⬜ Restart k3s-agent on worker-1
2. ⬜ Verify worker-1 pod scheduling
3. ⬜ Restart k3s-agent on worker-2
4. ⬜ Verify worker-2 pod scheduling
5. ⬜ Check node-exporter pods

### Phase 4: Workload Distribution (30 minutes)
1. ⬜ Drain master of non-system pods
2. ⬜ Verify pods reschedule to workers
3. ⬜ Check pod health on workers
4. ⬜ Verify service accessibility

### Phase 5: DNS Fix (15 minutes)
1. ⬜ Update CoreDNS configmap
2. ⬜ Restart CoreDNS pods
3. ⬜ Verify DNS resolution

### Phase 6: Validation (30 minutes)
1. ⬜ Run infrastructure validation
2. ⬜ Test all service endpoints
3. ⬜ Verify monitoring stack
4. ⬜ Check data engineering stack
5. ⬜ Update documentation

## Risk Assessment

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Master upgrade fails | High | Medium | Full backup, rollback plan |
| Data loss during upgrade | High | Low | Multiple backups, PV snapshots |
| Service downtime | Medium | High | Maintenance window, user notification |
| Version incompatibility | Medium | Low | Test on dev first |
| Network issues post-upgrade | Low | Low | Document network config |

## Testing Checklist

After upgrade:
- [ ] All nodes show Ready status
- [ ] All nodes show same k3s version
- [ ] Pods schedule on all nodes
- [ ] node-exporter runs on all nodes
- [ ] No CreateContainerConfigError
- [ ] Services respond correctly
- [ ] NiFi UI accessible (port 8080)
- [ ] Grafana UI accessible (port 3000)
- [ ] Trino queries execute
- [ ] MinIO storage accessible
- [ ] PostgreSQL connections work
- [ ] No DNS warnings in events

## Rollback Plan

If upgrade fails:

1. **Restore from backup**:
```powershell
# Restore k3s server
ssh hezekiah@192.168.0.120
sudo systemctl stop k3s
sudo /usr/local/bin/k3s-uninstall.sh
# Reinstall v1.28.4 and restore data
```

2. **Redeploy from code**:
```powershell
.\Make.ps1 destroy -Environment dev
.\Make.ps1 apply -Environment dev
# Restore application data
```

## Commands for Execution

### Pre-Upgrade Backup
```powershell
# Backup cluster state
kubectl get all -A -o yaml > "cluster-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').yaml"

# Backup persistent volumes
kubectl get pv,pvc -A -o yaml > "pv-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').yaml"

# Export important configs
kubectl -n kube-system get configmap coredns -o yaml > coredns-backup.yaml
kubectl -n kube-system get secret -o yaml > secrets-backup.yaml
```

### Master Upgrade Commands
```bash
# On master node (pi-master)
sudo systemctl stop k3s
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.32.5+k3s1 sh -s - server \
  --disable traefik \
  --disable servicelb \
  --write-kubeconfig-mode 644

sudo systemctl restart k3s
sudo systemctl status k3s

# Verify upgrade
k3s --version
kubectl version --short
kubectl get nodes
```

### Worker Agent Restart
```bash
# On each worker node
sudo systemctl restart k3s-agent
sudo systemctl status k3s-agent
sudo journalctl -u k3s-agent -n 50
```

### Post-Upgrade Verification
```powershell
# Check versions
kubectl get nodes -o wide

# Check pod distribution
kubectl get pods -A -o wide | Format-Table -AutoSize

# Check events
kubectl get events -A --sort-by='.lastTimestamp' | Select-Object -Last 50

# Run validation
.\scripts\validate-infrastructure.ps1
```

## Next Steps

**IMMEDIATE ACTIONS REQUIRED**:

1. **Decision Point**: Choose resolution option (Recommend Option 1: Master Upgrade)
2. **Schedule Maintenance Window**: 2-3 hours recommended
3. **Execute Backups**: Before any changes
4. **Begin Upgrade Process**: Follow phase plan above

**After Resolution**:

1. Update DEPLOYMENT-STATUS.md with final cluster state
2. Document version management procedures
3. Add version check to validation scripts
4. Set up automated version monitoring
5. Create runbook for future upgrades

## Additional Notes

- The cluster has been running for 165 days (master) and 162 days (workers)
- Worker nodes were likely upgraded independently at some point
- Consider implementing a version management strategy
- Add pre-deployment version checks to prevent this issue

## References

- [Kubernetes Version Skew Policy](https://kubernetes.io/releases/version-skew-policy/)
- [k3s Upgrade Guide](https://docs.k3s.io/upgrades)
- k3s Release Notes: [v1.28](https://github.com/k3s-io/k3s/releases/tag/v1.28.4%2Bk3s1) → [v1.32](https://github.com/k3s-io/k3s/releases/tag/v1.32.5%2Bk3s1)

---

**Status**: ANALYSIS COMPLETE - AWAITING DECISION ON RESOLUTION PATH
