version: 2
config:
  transport: ssh
  ssh:
    user: hezekiah
    private-key: /home/boltuser/.ssh/pi_k3s_cluster_rsa
    host-key-check: false
    run-as: root

groups:
  - name: cluster
    groups:
      - name: masters
        targets:
%{ for name, node in nodes ~}
%{ if node.role == "master" ~}
          - uri: ${node.ip}
            name: ${name}
            alias: ${name}.cluster.local
            vars:
              role: ${node.role}
              k3s_role: server
              environment: ${environment}
%{ endif ~}
%{ endfor ~}
        vars:
          k3s_server_args: "--disable traefik --disable servicelb"

      - name: workers
        targets:
%{ for name, node in nodes ~}
%{ if node.role == "worker" ~}
          - uri: ${node.ip}
            name: ${name}
            alias: ${name}.cluster.local
            vars:
              role: ${node.role}
              k3s_role: agent
              environment: ${environment}
%{ endif ~}
%{ endfor ~}
        vars:
          k3s_agent_args: ""
    vars:
      cluster_name: pi-k3s-${environment}
      cluster_domain: cluster.local
      environment: ${environment}
