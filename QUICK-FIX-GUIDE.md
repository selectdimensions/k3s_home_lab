# Worker Node Deployment Fix - Quick Start Guide

## 🎯 Problem Summary

Your K3s cluster has a **critical version skew issue**:
- **Master**: k3s v1.28.4 (June 2023)
- **Workers**: k3s v1.32.5 (December 2024)
- **Impact**: Worker nodes show "Ready" but cannot run pods due to API incompatibility

**Result**: All 11 pods are running on master node only, workers are non-functional.

## 📋 Quick Diagnosis

```powershell
# Verify the issue
kubectl get nodes -o wide
kubectl get pods -A -o wide | Select-String "pi-worker"
kubectl describe pod -n monitoring $(kubectl get pod -n monitoring -l app.kubernetes.io/name=node-exporter -o name | Select-Object -First 1)
```

Expected output: CreateContainerConfigError with "services have not yet been read at least once"

## 🚀 Quick Fix (Recommended: Master Upgrade)

### Option A: Automated Upgrade Script (EASIEST)

```powershell
# Run the automated upgrade script
.\Upgrade-K3sMaster.ps1 -BackupFirst $true

# This will:
# 1. Create full cluster backup
# 2. Upgrade master to v1.32.5
# 3. Restart workers to reconnect
# 4. Verify the upgrade
```

**Time**: ~30 minutes including validation

### Option B: Manual Upgrade Steps

#### 1. Backup Cluster (5 minutes)
```powershell
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
mkdir "backups\pre-upgrade-$timestamp"
kubectl get all -A -o yaml > "backups\pre-upgrade-$timestamp\all-resources.yaml"
kubectl get pv,pvc -A -o yaml > "backups\pre-upgrade-$timestamp\persistent-volumes.yaml"
```

#### 2. Upgrade Master Node (10 minutes)
```bash
# SSH to master
ssh hezekiah@192.168.0.120

# Stop k3s
sudo systemctl stop k3s

# Upgrade to v1.32.5
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

#### 3. Restart Worker Agents (5 minutes)
```bash
# On pi-worker-1
ssh hezekiah@192.168.0.121
sudo systemctl restart k3s-agent
sudo systemctl status k3s-agent

# On pi-worker-2
ssh hezekiah@192.168.0.122
sudo systemctl restart k3s-agent
sudo systemctl status k3s-agent
```

#### 4. Verify Upgrade (5 minutes)
```powershell
# Check all nodes have same version
kubectl get nodes -o custom-columns=NAME:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion

# Wait for pods to redistribute
Start-Sleep -Seconds 30
kubectl get pods -A -o wide

# Check node-exporter pods should now be Running on workers
kubectl get pods -n monitoring -l app.kubernetes.io/name=node-exporter
```

#### 5. Distribute Workloads (Optional, 10 minutes)
```powershell
# Drain master to force pod rescheduling
kubectl drain pi-master --ignore-daemonsets --delete-emptydir-data

# Watch pods move to workers
kubectl get pods -A -o wide --watch

# Uncordon master
kubectl uncordon pi-master
```

## 📊 Expected Results

After successful upgrade:

```
✅ All nodes show v1.32.5+k3s1
✅ node-exporter pods Running on all 3 nodes
✅ Application pods distributed across workers
✅ No CreateContainerConfigError events
✅ Services remain accessible
```

## 🔍 Validation Commands

```powershell
# Check version consistency
kubectl get nodes -o wide

# Verify pod distribution
kubectl get pods -A -o wide | Format-Table -AutoSize

# Check for errors
kubectl get events -A --sort-by='.lastTimestamp' | Select-Object -Last 20

# Test services
kubectl get svc -A

# Port forward to test apps
kubectl -n monitoring port-forward svc/grafana 3000:3000
kubectl -n data-engineering port-forward svc/nifi 8080:8080
```

## ⏱️ Time Estimates

| Phase | Time | Risk |
|-------|------|------|
| Backup | 5 min | Low |
| Master Upgrade | 10 min | Medium |
| Worker Restart | 5 min | Low |
| Verification | 5 min | Low |
| Workload Distribution | 10 min | Low |
| **Total** | **35 min** | **Medium** |

## 🆘 Troubleshooting

### Issue: SSH Connection Failed
```powershell
# Configure SSH key
ssh-copy-id hezekiah@192.168.0.120

# Or use password authentication
ssh hezekiah@192.168.0.120
```

### Issue: Master Upgrade Failed
```bash
# Check logs
sudo journalctl -u k3s -xe

# Rollback: Reinstall v1.32.5
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.32.5+k3s1 sh -s - server \
  --disable traefik --disable servicelb --write-kubeconfig-mode 644
```

### Issue: Pods Still Not Scheduling on Workers
```powershell
# Check node status
kubectl describe node pi-worker-1
kubectl describe node pi-worker-2

# Check for taints
kubectl get nodes -o json | ConvertFrom-Json | Select-Object -ExpandProperty items | ForEach-Object { $_.spec.taints }

# Remove taints if present
kubectl taint nodes pi-worker-1 node.kubernetes.io/unschedulable:NoSchedule-
```

### Issue: Services Not Accessible
```powershell
# Check pod logs
kubectl logs -n data-engineering deployment/nifi
kubectl logs -n monitoring deployment/grafana

# Restart problematic pods
kubectl -n data-engineering rollout restart deployment/nifi
kubectl -n monitoring rollout restart deployment/grafana
```

## 📁 Documentation References

- **Full Analysis**: `WORKER-NODE-ANALYSIS.md` - Comprehensive analysis and all resolution options
- **Upgrade Script**: `Upgrade-K3sMaster.ps1` - Automated upgrade with backups
- **Deployment Status**: `DEPLOYMENT-STATUS.md` - Updated with current issues
- **Make Commands**: `Make.ps1` - Project automation commands

## 🎓 Lessons Learned

**Prevention for Future**:
1. Add version check to deployment validation scripts
2. Implement version pinning in infrastructure code
3. Always upgrade master before workers
4. Test upgrades in dev environment first
5. Document version management procedures

## 🔗 Additional Resources

- [Kubernetes Version Skew Policy](https://kubernetes.io/releases/version-skew-policy/)
- [k3s Upgrade Documentation](https://docs.k3s.io/upgrades)
- [k3s v1.32.5 Release Notes](https://github.com/k3s-io/k3s/releases/tag/v1.32.5%2Bk3s1)

---

## 🎬 Ready to Start?

**Choose your approach**:

1. **Automated** (Recommended for first-time):
   ```powershell
   .\Upgrade-K3sMaster.ps1
   ```

2. **Manual** (If you want full control):
   Follow "Option B: Manual Upgrade Steps" above

3. **Alternative** (Downgrade workers instead):
   See `WORKER-NODE-ANALYSIS.md` for downgrade procedure

**Need help?** Check `WORKER-NODE-ANALYSIS.md` for detailed troubleshooting and rollback procedures.

---

**Status**: Ready for execution 🚀
