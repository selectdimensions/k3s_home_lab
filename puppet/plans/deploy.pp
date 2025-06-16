# Deployment plan for Pi cluster
plan pi_cluster_automation::deploy (
  TargetSpec $targets,
  String $deploy_env = 'prod',
  Boolean $skip_k3s = false,
) {
  out::message("Starting deployment on environment: ${deploy_env}")
  
  # Get target information from inventory
  $target_list = get_targets($targets)
  
  # Group targets by role using inventory variables
  $masters = $target_list.filter |$target| {
    $target.vars['role'] == 'master'
  }
  
  $workers = $target_list.filter |$target| {
    $target.vars['role'] == 'worker'
  }
  
  out::message("Found ${masters.size} master(s) and ${workers.size} worker(s)")
    # Phase 1: Base configuration using commands
  out::message("Phase 1: Configuring base system on all nodes")
  
  # Update package cache and install essential packages
  run_command('apt-get update', $targets)
  run_command('apt-get install -y curl wget git vim htop apt-transport-https ca-certificates software-properties-common', $targets)
  
  # Enable cgroups for K3s
  run_command('if ! grep -q "cgroup_enable=memory" /boot/cmdline.txt; then sed -i \'s/$/ cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1/\' /boot/cmdline.txt; echo "Cgroups enabled - reboot required"; fi', $targets)
  
  # Disable swap
  run_command('systemctl disable dphys-swapfile || true', $targets)
  run_command('dphys-swapfile swapoff || true', $targets)
    # Phase 2: Install K3s on master using commands
  unless $skip_k3s {
    out::message("Phase 2: Installing K3s on master nodes")
    
    # Install K3s on masters
    run_command('curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.28.4+k3s1 sh -s - server --write-kubeconfig-mode 644 --disable traefik --disable servicelb', $masters)
    
    # Wait for K3s to be ready
    out::message("Waiting for K3s server to be ready...")
    run_command('while ! kubectl get nodes; do sleep 5; done', $masters)    # Get token from master for workers
    if $workers.size > 0 {
      if $masters.size == 0 {
        fail("Cannot install workers without master nodes")
      }
      
      out::message("Getting K3s token for worker nodes")
      $token_result = run_command('cat /var/lib/rancher/k3s/server/node-token', $masters[0])
      $k3s_token = $token_result[$masters[0]]['stdout'].strip()
      $master_ip = $masters[0].name
        # Phase 3: Install K3s on workers using commands
      out::message("Phase 3: Installing K3s on worker nodes")
      
      # Install K3s agent on workers
      run_command("curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.28.4+k3s1 K3S_URL=https://${master_ip}:6443 K3S_TOKEN=${k3s_token} sh -s - agent", $workers)
    }
  }
  
  out::message("Deployment complete!")
}