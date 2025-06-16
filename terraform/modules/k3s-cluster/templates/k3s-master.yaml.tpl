# K3s Master Node Configuration
server: https://${node_ip}:6443
cluster-cidr: ${cluster_cidr}
service-cidr: ${service_cidr}
cluster-dns: ${cluster_dns}
cluster-init: true
node-name: ${node_name}
node-ip: ${node_ip}
token: ${k3s_token}
disable: ${disable_components}
write-kubeconfig-mode: "0644"
disable-cloud-controller: true
disable-network-policy: true

# Kubelet configuration
kubelet-arg:
  - "max-pods=110"
  - "node-status-update-frequency=10s"
  - "image-gc-high-threshold=85"
  - "image-gc-low-threshold=80"

# API server configuration
kube-apiserver-arg:
  - "enable-admission-plugins=NodeRestriction,ResourceQuota,LimitRanger"
  - "audit-log-maxage=30"
  - "audit-log-maxbackup=3"
  - "audit-log-maxsize=100"

# Controller manager configuration
kube-controller-manager-arg:
  - "bind-address=0.0.0.0"
  - "node-cidr-mask-size=24"

# Scheduler configuration
kube-scheduler-arg:
  - "bind-address=0.0.0.0"
