# Base profile for all Pi nodes
class profiles::base (
  String $timezone = lookup('pi_cluster::timezone'),
) {
  # Set timezone
  class { 'timezone':
    timezone => $timezone,
  }
  
  # Essential packages
  $base_packages = [
    'curl',
    'wget',
    'git',
    'vim',
    'htop',
    'iotop',
    'ncdu',
    'tmux',
    'python3-pip',
    'jq',
  ]
  
  package { $base_packages:
    ensure => present,
  }
  
  # Configure system limits
  file { '/etc/security/limits.d/pi-cluster.conf':
    ensure  => file,
    content => template('profiles/limits.conf.erb'),
  }
  
  # Enable cgroups for K3s
  augeas { 'enable_cgroups':
    context => '/files/boot/cmdline.txt',
    changes => [
      'set /files/boot/cmdline.txt/1 "$(cat /boot/cmdline.txt) cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1"',
    ],
    onlyif  => 'match /files/boot/cmdline.txt/*[. =~ regexp(".*cgroup_enable=memory.*")] size == 0',
    notify  => Reboot['after_cgroups'],
  }
  
  reboot { 'after_cgroups':
    when => refreshed,
  }
  
  # Disable swap
  exec { 'disable_swap':
    command => '/sbin/dphys-swapfile swapoff && /sbin/dphys-swapfile uninstall',
    onlyif  => '/usr/bin/test -f /var/swap',
  }
  
  service { 'dphys-swapfile':
    ensure => stopped,
    enable => false,
  }
}