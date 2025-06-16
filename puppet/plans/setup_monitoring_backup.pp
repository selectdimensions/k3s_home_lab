# Plan to setup monitoring and backup procedures
plan pi_cluster_automation::setup_monitoring_backup (
  TargetSpec $targets,
  String $monitoring_namespace = 'monitoring',
  Boolean $setup_monitoring = true,
  Boolean $setup_backup = true,
  String $backup_schedule = '0 2 * * *', # Daily at 2 AM
  Integer $backup_retention = 7,
) {
  out::message("Setting up monitoring and backup procedures")
  
  # Get target information
  $target_list = get_targets($targets)
  $masters = $target_list.filter |$target| {
    $target.vars['role'] == 'master'
  }
  
  if $masters.size == 0 {
    fail("No master nodes found in targets")
  }
  
  $master_node = $masters[0]
  out::message("Using master node: ${master_node.name}")
  
  # Phase 1: Setup monitoring stack
  if $setup_monitoring {
    out::message("Phase 1: Setting up monitoring stack")
    
    # Deploy monitoring components
    $monitor_result = run_task('pi_cluster_automation::setup_monitoring', $master_node, {
      'stack_components' => 'all',
      'namespace' => $monitoring_namespace,
      'persistent_storage' => true,
      'retention_days' => 15
    })
    
    out::message("Monitoring stack deployment result:")
    $monitor_result.each |$result| {
      out::message("${result.target.name}: ${result.value['_output']}")
    }
  }
  
  # Phase 2: Setup backup procedures
  if $setup_backup {
    out::message("Phase 2: Setting up backup procedures")
    
    # Create backup directory structure on all nodes
    run_command('mkdir -p /opt/backups', $targets)
    run_command('mkdir -p /opt/scripts', $targets)
    
    # Create backup script on master node
    $backup_script = @("BACKUP_SCRIPT")
#!/bin/bash
# Automated cluster backup script
/opt/puppetlabs/bin/bolt task run pi_cluster_automation::backup_cluster \
  --targets ${master_node.name} \
  backup_type=full \
  backup_location=/opt/backups \
  retention_days=${backup_retention}
| BACKUP_SCRIPT
    
    # Write backup script to master
    write_file('/opt/scripts/cluster-backup.sh', $backup_script, $master_node)
    run_command('chmod +x /opt/scripts/cluster-backup.sh', $master_node)
    
    # Setup cron job for automated backups
    $cron_entry = "${backup_schedule} root /opt/scripts/cluster-backup.sh >> /var/log/cluster-backup.log 2>&1"
    run_command("echo '${cron_entry}' > /etc/cron.d/cluster-backup", $master_node)
    
    # Perform initial backup
    run_task('pi_cluster_automation::backup_cluster', $master_node, {
      'backup_type' => 'full',
      'backup_location' => '/opt/backups',
      'retention_days' => $backup_retention
    })
  }
  
  # Phase 3: Setup health monitoring
  out::message("Phase 3: Setting up health monitoring")
  
  # Create health check script
  $health_script = @("HEALTH_SCRIPT")
#!/bin/bash
# Cluster health monitoring script
echo "=== Cluster Health Check - $(date) ==="

# Check cluster status
/opt/puppetlabs/bin/bolt task run pi_cluster_automation::cluster_status \
  --targets ${targets.join(',')}

# Check monitoring stack health if deployed
if [ "$1" = "monitoring" ]; then
  echo "=== Monitoring Stack Status ==="
  kubectl get pods -n ${monitoring_namespace} 2>/dev/null || echo "Monitoring namespace not found"
fi

echo "=== Health Check Complete ==="
| HEALTH_SCRIPT
  
  write_file('/opt/scripts/health-check.sh', $health_script, $master_node)
  run_command('chmod +x /opt/scripts/health-check.sh', $master_node)
  
  # Setup health check cron (every 15 minutes)
  $health_cron = "*/15 * * * * root /opt/scripts/health-check.sh >> /var/log/health-check.log 2>&1"
  run_command("echo '${health_cron}' > /etc/cron.d/health-check", $master_node)
  
  # Phase 4: Create alert rules if monitoring is enabled
  if $setup_monitoring {
    out::message("Phase 4: Setting up alert rules")
    
    # Create basic alert rules
    $alert_rules = @("ALERT_RULES")
groups:
- name: cluster-alerts
  rules:
  - alert: NodeDown
    expr: up == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Node {{ \$labels.instance }} is down"
      description: "Node {{ \$labels.instance }} has been down for more than 1 minute"
  
  - alert: HighMemoryUsage
    expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes > 0.9
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High memory usage on {{ \$labels.instance }}"
      description: "Memory usage is above 90% for more than 5 minutes"
  
  - alert: HighDiskUsage
    expr: (node_filesystem_size_bytes - node_filesystem_avail_bytes) / node_filesystem_size_bytes > 0.9
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High disk usage on {{ \$labels.instance }}"
      description: "Disk usage is above 90% for more than 5 minutes"
  
  - alert: PodCrashLooping
    expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Pod {{ \$labels.pod }} is crash looping"
      description: "Pod {{ \$labels.pod }} in namespace {{ \$labels.namespace }} is restarting frequently"
| ALERT_RULES
    
    # Apply alert rules to Prometheus
    run_command("kubectl create configmap prometheus-rules -n ${monitoring_namespace} --from-literal=alerts.yml='${alert_rules}' --dry-run=client -o yaml | kubectl apply -f -", $master_node)
  }
  
  out::message("✅ Monitoring and backup setup completed!")
  out::message("📊 Monitoring access:")
  out::message("  Prometheus: kubectl port-forward svc/prometheus 9090:9090 -n ${monitoring_namespace}")
  out::message("  Grafana: kubectl port-forward svc/grafana 3000:3000 -n ${monitoring_namespace}")
  out::message("💾 Backup schedule: ${backup_schedule}")
  out::message("📁 Backup location: /opt/backups")
  out::message("📋 Health checks: every 15 minutes")
}
