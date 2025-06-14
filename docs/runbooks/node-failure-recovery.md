# Node Failure Recovery Runbook

## Overview
This runbook describes the process for recovering from a node failure in the Pi cluster.

## Prerequisites
- Access to the cluster
- SSH access to healthy nodes
- Backup of failed node's data (if applicable)

## Detection
Node failure is detected through:
1. Prometheus alerts (NodeDown)
2. `kubectl get nodes` showing NotReady status
3. Physical inspection

## Recovery Steps

### 1. Assess the Situation
```bash
# Check node status
kubectl get nodes

# Check recent events
kubectl get events --sort-by='.lastTimestamp'

# Check node conditions
kubectl describe node <failed-node>
```

### 2. Hardware Recovery

#### Option A: Soft Recovery
```bash
# Try to SSH into the node
ssh pi@<node-ip>

# If accessible, check system logs
sudo journalctl -xe

# Restart K3s service
sudo systemctl restart k3s-agent
```

#### Option B: Hard Recovery
1. Power cycle the Raspberry Pi
2. Wait for boot (2-3 minutes)
3. Verify connectivity: `ping <node-ip>`

### 3. Node Replacement
If hardware failure is confirmed:

```bash
# Cordon the node
kubectl cordon <failed-node>

# Drain workloads
kubectl drain <failed-node> --ignore-daemonsets --delete-emptydir-data

# Remove from cluster
kubectl delete node <failed-node>

# Prepare new SD card
./scripts/prepare-sd-card.sh <node-name> <node-ip>

# Re-run Ansible playbook
cd ansible
ansible-playbook -i inventories/prod/hosts.yml playbooks/install-k3s.yml --limit <node-name>
```

### 4. Verification
```bash
# Verify node joined cluster
kubectl get nodes

# Check pod distribution
kubectl get pods -A -o wide | grep <node-name>

# Run cluster health check
./scripts/health-check.sh
```

## Rollback
If recovery fails:
1. Remove problematic node from load balancer
2. Scale up deployments on remaining nodes
3. Schedule hardware replacement

## Post-Incident
1. Update monitoring alerts if needed
2. Document failure cause
3. Update hardware inventory
4. Schedule preventive maintenance

## Benefits of This Enhanced Structure

1. **CI/CD Pipeline**: Automated testing and deployment with GitHub Actions
2. **GitOps**: ArgoCD for declarative application deployment
3. **Disaster Recovery**: Velero for backup/restore capabilities
4. **Monitoring**: Comprehensive monitoring with Prometheus, Grafana, and Loki
5. **Security**: Security scanning, secrets management, and network policies
6. **Multi-Environment**: Support for dev, staging, and production
7. **Testing**: Automated testing with Molecule, Terratest, and integration tests
8. **Documentation**: Comprehensive runbooks and architecture docs
9. **Resilience**: Automated health checks and recovery procedures
10. **Ease of Use**: Makefile for common operations

This structure provides a production-ready, resilient, and easily maintainable Pi cluster infrastructure.