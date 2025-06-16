# K3s Cluster Deployment Plan
# Deploys and configures K3s on Pi cluster nodes
#
# Usage:
#   bolt plan run pi_cluster_automation::k3s_deploy targets=all -i inventory.yaml
#   bolt plan run pi_cluster_automation::k3s_deploy targets=pi-master,pi-worker-1 -i inventory.yaml

plan pi_cluster_automation::k3s_deploy (
  TargetSpec $targets,
  String $environment = 'production',
  String $k3s_version = 'v1.28.4+k3s1',
  String $k3s_token = '',
  String $cluster_cidr = '10.42.0.0/16',
  String $service_cidr = '10.43.0.0/16',
  String $cluster_dns = '10.43.0.10',
  Boolean $install_traefik = false,
  Boolean $install_local_storage = true,
  Boolean $debug_mode = false,
) {

  out::message("🚀 Starting K3s cluster deployment")
  out::message("Environment: ${environment}")
  out::message("K3s Version: ${k3s_version}")
  out::message("Targets: ${targets}")

  # Get target information
  $target_list = get_targets($targets)
  $master_nodes = $target_list.filter |$target| {
    $target.vars['role'] == 'master'
  }
  $worker_nodes = $target_list.filter |$target| {
    $target.vars['role'] == 'worker'
  }

  out::message("📊 Cluster topology:")
  out::message("  Masters: ${master_nodes.map |$t| { $t.name }.join(', ')}")
  out::message("  Workers: ${worker_nodes.map |$t| { $t.name }.join(', ')}")

  # Phase 1: Pre-installation checks and preparation
  out::message("🔍 Phase 1: Pre-installation system checks")

  # Check system requirements
  $prereq_results = run_task('pi_cluster_automation::check_k3s_prereqs', $targets, {
    'debug' => $debug_mode
  })

  # Verify all nodes passed prerequisites
  $failed_nodes = $prereq_results.filter |$result| {
    $result.value['status'] != 'ready'
  }

  if $failed_nodes.length > 0 {
    fail_plan("❌ Prerequisites failed on nodes: ${failed_nodes.map |$r| { $r.target.name }.join(', ')}")
  }

  out::message("✅ All nodes passed prerequisites check")

  # Phase 2: Install K3s on master node(s)
  out::message("🎯 Phase 2: Installing K3s master")

  if $master_nodes.length == 0 {
    fail_plan("❌ No master nodes found. At least one node must have role=master")
  }

  # Generate or use provided K3s token
  $actual_k3s_token = if $k3s_token == '' {
    # Generate random token if not provided
    run_command('openssl rand -hex 32', $master_nodes[0]).first.value['stdout'].strip
  } else {
    $k3s_token
  }

  out::message("🔑 Using K3s token: ${actual_k3s_token[0,8]}...")

  # Install K3s on master nodes
  $master_install_params = {
    'k3s_version' => $k3s_version,
    'k3s_token' => $actual_k3s_token,
    'cluster_cidr' => $cluster_cidr,
    'service_cidr' => $service_cidr,
    'cluster_dns' => $cluster_dns,
    'install_traefik' => $install_traefik,
    'install_local_storage' => $install_local_storage,
    'debug_mode' => $debug_mode,
    'environment' => $environment,
  }

  $master_results = run_task('pi_cluster_automation::install_k3s_master',
    $master_nodes, $master_install_params)

  # Check master installation results
  $failed_masters = $master_results.filter |$result| {
    $result.value['status'] != 'success'
  }

  if $failed_masters.length > 0 {
    fail_plan("❌ K3s master installation failed on: ${failed_masters.map |$r| { $r.target.name }.join(', ')}")
  }

  out::message("✅ K3s master installed successfully")

  # Wait for master to be ready
  out::message("⏳ Waiting for K3s master to be ready...")
  run_task('pi_cluster_automation::wait_for_k3s_ready', $master_nodes, {
    'timeout' => 300,
    'debug' => $debug_mode
  })

  # Phase 3: Install K3s on worker nodes
  if $worker_nodes.length > 0 {
  out::message("👥 Phase 3: Installing K3s workers")

    # Get master node IP for worker join
    $master_ip = $master_nodes[0].vars.get('ansible_host') ? {
      undef   => $master_nodes[0].name,
      default => $master_nodes[0].vars['ansible_host']
    }

    $worker_install_params = {
      'k3s_version' => $k3s_version,
      'k3s_token' => $actual_k3s_token,
      'master_ip' => $master_ip,
      'debug_mode' => $debug_mode,
      'environment' => $environment,
    }

    $worker_results = run_task('pi_cluster_automation::install_k3s_worker',
      $worker_nodes, $worker_install_params)

    # Check worker installation results
    $failed_workers = $worker_results.filter |$result| {
      $result.value['status'] != 'success'
    }

    if $failed_workers.length > 0 {
      fail_plan("❌ K3s worker installation failed on: ${failed_workers.map |$r| { $r.target.name }.join(', ')}")
    }

    out::message("✅ K3s workers installed successfully")

    # Wait for workers to join cluster
    out::message("⏳ Waiting for workers to join cluster...")
    run_task('pi_cluster_automation::wait_for_nodes_ready', $master_nodes, {
      'expected_nodes' => $target_list.length,
      'timeout' => 300,
      'debug' => $debug_mode
    })
  } else {
    out::message("ℹ️  No worker nodes specified, running single-node cluster")
  }

  # Phase 4: Post-installation configuration
  out::message("⚙️  Phase 4: Post-installation configuration")

  # Apply node labels
  $label_results = run_task('pi_cluster_automation::apply_node_labels', $targets, {
    'debug' => $debug_mode
  })

  # Install essential cluster components
  $components_params = {
    'metallb_ip_range' => lookup('metallb_ip_range', String, 'first', '192.168.0.200-192.168.0.250'),
    'install_cert_manager' => true,
    'install_metrics_server' => true,
    'environment' => $environment,
    'debug' => $debug_mode
  }

  run_task('pi_cluster_automation::install_cluster_components',
    $master_nodes, $components_params)

  # Phase 5: Validation and cluster status
  out::message("🔍 Phase 5: Cluster validation")

  # Get cluster status
  $cluster_status = run_task('pi_cluster_automation::get_cluster_status',
    $master_nodes, { 'debug' => $debug_mode })

  out::message("📊 Cluster Status:")
  $cluster_status.each |$result| {
    $status = $result.value
    out::message("  Nodes: ${status['nodes']}")
    out::message("  Pods: ${status['pods']}")
    out::message("  Services: ${status['services']}")
    out::message("  Version: ${status['version']}")
  }

  # Generate kubeconfig for local access
  out::message("📁 Generating kubeconfig...")
  $kubeconfig_result = run_task('pi_cluster_automation::generate_kubeconfig',
    $master_nodes, {
      'environment' => $environment,
      'cluster_name' => lookup('cluster_name', String, 'first', 'pi-k3s-cluster')
    })

  # Phase 6: Final validation tests
  out::message("🧪 Phase 6: Running validation tests")

  $validation_results = run_task('pi_cluster_automation::validate_cluster',
    $master_nodes, { 'debug' => $debug_mode })

  $validation_failed = $validation_results.filter |$result| {
    $result.value['status'] != 'success'
  }

  if $validation_failed.length > 0 {
    out::message("⚠️  Some validation tests failed:")
    $validation_failed.each |$result| {
      out::message("  ${result.target.name}: ${result.value['message']}")
    }
  } else {
    out::message("✅ All validation tests passed")
  }

  # Summary
  out::message("")
  out::message("🎉 K3s cluster deployment completed!")
  out::message("═══════════════════════════════════════")
  out::message("Cluster Name: ${lookup('cluster_name', String, 'first', 'pi-k3s-cluster')}")
  out::message("Environment: ${environment}")
  out::message("Master Nodes: ${master_nodes.length}")
  out::message("Worker Nodes: ${worker_nodes.length}")
  out::message("Total Nodes: ${target_list.length}")
  out::message("")
  out::message("Next Steps:")
  out::message("1. Copy kubeconfig: kubectl config use-context pi-k3s-${environment}")
  out::message("2. Check nodes: kubectl get nodes")
  out::message("3. Deploy applications: ./Make.ps1 deploy-data-platform")
  out::message("")

  return {
    'status' => 'success',
    'cluster_name' => lookup('cluster_name', String, 'first', 'pi-k3s-cluster'),
    'environment' => $environment,
    'master_nodes' => $master_nodes.map |$t| { $t.name },
    'worker_nodes' => $worker_nodes.map |$t| { $t.name },
    'k3s_version' => $k3s_version,
    'kubeconfig' => $kubeconfig_result[0].value['kubeconfig_path']
  }
}
