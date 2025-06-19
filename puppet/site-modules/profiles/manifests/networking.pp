# puppet/site-modules/profiles/manifests/networking.pp
# Network configuration for cluster nodes
class profiles::networking {
  # Configure DNS settings
  file { '/etc/systemd/resolved.conf':
    ensure  => file,
    content => epp('profiles/resolved.conf.epp'),
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
