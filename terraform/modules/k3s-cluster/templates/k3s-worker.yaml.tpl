# K3s Worker Node Configuration
server: https://${master_ip}:6443
node-name: ${node_name}
node-ip: ${node_ip}
token: ${k3s_token}

# Kubelet configuration
kubelet-arg:
  - "max-pods=110"
  - "node-status-update-frequency=10s"
  - "image-gc-high-threshold=85"
  - "image-gc-low-threshold=80"
  - "container-log-max-size=10Mi"
  - "container-log-max-files=5"
