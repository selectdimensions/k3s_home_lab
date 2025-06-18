# puppet/site-modules/profiles/manifests/networking.pp
class profiles::networking {
  # Network configuration for cluster nodes

  # Configure DNS settings
  file { '/etc/systemd/resolved.conf':
    ensure  => file,
    content => template('profiles/resolved.conf.erb'),
    notify  => Service['systemd-resolved'],
  }

  service { 'systemd-resolved':
    ensure => running,
    enable => true,
  }

  # Enable IP forwarding for K3s
  sysctl { 'net.ipv4.ip_forward':
    value => '1',
  }

  sysctl { 'net.bridge.bridge-nf-call-iptables':
    value => '1',
  }
}

# puppet/site-modules/profiles/manifests/security.pp
class profiles::security {
  # Basic security hardening for cluster nodes

  # Install and configure fail2ban
  package { 'fail2ban':
    ensure => present,
  }

  service { 'fail2ban':
    ensure  => running,
    enable  => true,
    require => Package['fail2ban'],
  }

  # Configure SSH security
  file_line { 'ssh_disable_root_login':
    path  => '/etc/ssh/sshd_config',
    line  => 'PermitRootLogin no',
    match => '^#?PermitRootLogin',
    notify => Service['ssh'],
  }

  file_line { 'ssh_disable_password_auth':
    path  => '/etc/ssh/sshd_config',
    line  => 'PasswordAuthentication no',
    match => '^#?PasswordAuthentication',
    notify => Service['ssh'],
  }

  service { 'ssh':
    ensure => running,
    enable => true,
  }
}

# puppet/site-modules/profiles/manifests/monitoring_agent.pp
class profiles::monitoring_agent {
  # Install node_exporter for Prometheus monitoring

  # Create prometheus user
  user { 'prometheus':
    ensure     => present,
    system     => true,
    shell      => '/bin/false',
    home       => '/var/lib/prometheus',
    managehome => false,
  }

  # Download and install node_exporter
  archive { '/tmp/node_exporter.tar.gz':
    ensure          => present,
    source          => 'https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-arm64.tar.gz',
    extract         => true,
    extract_path    => '/opt',
    extract_command => 'tar xfz %s --strip-components=1',
    creates         => '/opt/node_exporter',
    cleanup         => true,
  }

  file { '/usr/local/bin/node_exporter':
    ensure  => link,
    target  => '/opt/node_exporter',
    require => Archive['/tmp/node_exporter.tar.gz'],
  }

  # Create systemd service
  file { '/etc/systemd/system/node_exporter.service':
    ensure  => file,
    content => @(SYSTEMD),
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
| SYSTEMD
    notify  => [Exec['systemd-reload'], Service['node_exporter']],
  }

  exec { 'systemd-reload':
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
  }

  service { 'node_exporter':
    ensure  => running,
    enable  => true,
    require => [File['/usr/local/bin/node_exporter'], File['/etc/systemd/system/node_exporter.service']],
  }
}
