# Robust deployment plan for Pi cluster with apt lock handling
plan pi_cluster_automation::deploy_robust (
  TargetSpec $targets,
  String $deploy_env = 'dev',
  Boolean $skip_k3s = false,
  Boolean $wait_for_apt = true,
) {
  out::message("Starting robust deployment on environment: ${deploy_env}")

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

  # Phase 0: Wait for any existing apt processes to complete
  if $wait_for_apt {
    out::message("Phase 0: Waiting for any existing apt processes to complete")
    run_command('while pgrep -x apt > /dev/null; do echo "Waiting for apt to finish..."; sleep 5; done', $targets, '_catch_errors' => true)
    run_command('while pgrep -x dpkg > /dev/null; do echo "Waiting for dpkg to finish..."; sleep 5; done', $targets, '_catch_errors' => true)
  }

  # Phase 1: Base configuration - do nodes sequentially to avoid apt conflicts
  out::message("Phase 1: Configuring base system on all nodes (sequential)")

  # Clear any stuck apt locks first
  run_command('rm -f /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock* || true', $targets, '_catch_errors' => true)

  # Update each node sequentially to avoid apt lock conflicts
  $target_list.each |$target| {
    out::message("Updating packages on ${target.name}")
    run_command('apt-get update && apt-get install -y curl wget git vim htop apt-transport-https ca-certificates software-properties-common', [$target], '_catch_errors' => true)
  }

  # Enable cgroups for K3s (safe to run in parallel)
  run_command('if ! grep -q "cgroup_enable=memory" /boot/cmdline.txt; then sed -i \'s/$/ cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1/\' /boot/cmdline.txt; echo "Cgroups enabled - reboot required"; fi', $targets, '_catch_errors' => true)

  # Disable swap (safe to run in parallel)
  run_command('systemctl disable dphys-swapfile || true', $targets, '_catch_errors' => true)
  run_command('dphys-swapfile swapoff || true', $targets, '_catch_errors' => true)

  # Phase 2: Install K3s on master
  unless $skip_k3s {
    out::message("Phase 2: Installing K3s on master nodes")

    # Install K3s on masters
    run_command('curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.28.4+k3s1 sh -s - server --write-kubeconfig-mode 644 --disable traefik --disable servicelb', $masters, '_catch_errors' => true)

    # Wait for K3s to be ready
    out::message("Waiting for K3s server to be ready...")
    run_command('timeout 120 bash -c "while ! kubectl get nodes; do sleep 5; done"', $masters, '_catch_errors' => true)

    # Get token from master for workers
    if $workers.size > 0 {
      if $masters.size == 0 {
        fail("Cannot install workers without master nodes")
      }

      out::message("Getting K3s token for worker nodes")
      $token_result = run_command('cat /var/lib/rancher/k3s/server/node-token', $masters[0], '_catch_errors' => true)
      $k3s_token = $token_result[$masters[0]]['stdout'].strip()
      $master_ip = $masters[0].name

      # Phase 3: Install K3s on workers
      out::message("Phase 3: Installing K3s on worker nodes")

      # Install K3s agent on workers sequentially to avoid conflicts
      $workers.each |$worker| {
        out::message("Installing K3s agent on ${worker.name}")
        run_command("curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.28.4+k3s1 K3S_URL=https://${master_ip}:6443 K3S_TOKEN=${k3s_token} sh -s - agent", [$worker], '_catch_errors' => true)
      }
    }
  }

  out::message("Robust deployment complete!")
}
