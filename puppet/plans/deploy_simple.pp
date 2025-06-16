# Simple deployment plan for Pi cluster
plan pi_cluster_automation::deploy_simple (
  TargetSpec $targets,
) {
  out::message("Starting deployment on targets: ${targets}")
  
  # Phase 1: Basic system check
  out::message("Phase 1: Running basic system checks")
  run_command('hostname && whoami && uptime', $targets)
  
  # Phase 2: Update package lists (basic example)
  out::message("Phase 2: Updating package lists")
  run_command('apt update', $targets)
  
  out::message("Deployment completed successfully!")
}
