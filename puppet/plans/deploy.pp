# Deployment plan for Pi cluster
plan pi_cluster_automation::deploy (
  TargetSpec $targets,
  String $environment = 'prod',
  Boolean $skip_k3s = false,
) {
  # Gather facts (commented out until facts task is available)
  # $target_facts = run_task('facts', $targets)
  
  # Group targets by role
  $masters = $targets.filter |$target| {
    $target.vars['role'] == 'master'
  }
  
  $workers = $targets.filter |$target| {
    $target.vars['role'] == 'worker'
  }
  
  # Phase 1: Base configuration
  out::message("Phase 1: Configuring base system on all nodes")
  apply($targets, _catch_errors => false) {
    include profiles::base
    include profiles::networking
    include profiles::security
  }
  
  # Phase 2: Install K3s on master
  unless $skip_k3s {
    out::message("Phase 2: Installing K3s on master nodes")
    apply($masters, _catch_errors => false) {
      include profiles::k3s_server
    }
    
    # Get token from master
    $token_result = run_command('cat /var/lib/rancher/k3s/server/node-token', $masters)
    $k3s_token = $token_result.first.stdout.chomp
    $master_ip = $masters.first.vars['ip']
    
    # Phase 3: Install K3s on workers
    out::message("Phase 3: Installing K3s on worker nodes")
    apply($workers, _catch_errors => false) {
      class { 'profiles::k3s_agent':
        server_url => "https://${master_ip}:6443",
        token      => $k3s_token,
      }
    }
  }
  
  # Phase 4: Deploy cluster services
  out::message("Phase 4: Deploying cluster services")
  run_task('pi_cluster_automation::deploy_services', $masters.first, {
    'environment' => $environment,
  })
  
  # Phase 5: Verify deployment
  out::message("Phase 5: Verifying deployment")
  $health_check = run_task('pi_cluster_automation::health_check', $targets)
  
  out::message("Deployment complete!")
  return $health_check
}