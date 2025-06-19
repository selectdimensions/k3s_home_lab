# puppet/site-modules/profiles/manifests/base.pp
# Base profile for all Pi nodes - simplified version
class profiles::base {
  # Essential packages for K3s
  $base_packages = [
    'curl',
    'wget',
    'git',
    'vim',
    'htop',
    'apt-transport-https',
    'ca-certificates',
    'software-properties-common',
  ]

  # Update package cache first
  exec { 'apt_update':
    command => '/usr/bin/apt-get update',
    path    => ['/usr/bin'],
  }

  package { $base_packages:
    ensure  => present,
    require => Exec['apt_update'],
  }

  # Enable cgroups for K3s (simplified)
  exec { 'enable_cgroups':
    command => '/bin/sed -i \'s/$/ cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1/\' /boot/cmdline.txt',
    unless  => '/bin/grep -q "cgroup_enable=memory" /boot/cmdline.txt',
    path    => ['/bin', '/usr/bin'],
    notify  => Exec['reboot_notice'],
  }

  exec { 'reboot_notice':
    command     => '/bin/echo "Reboot required for cgroups - run: sudo reboot"',
    refreshonly => true,
    path        => ['/bin', '/usr/bin'],
  }

  # Disable swap (required for K3s)
  service { 'dphys-swapfile':
    ensure => stopped,
    enable => false,
  }

  exec { 'disable_swap_now':
    command => '/sbin/dphys-swapfile swapoff',
    onlyif  => '/usr/bin/test -f /var/swap',
    path    => ['/sbin', '/usr/bin'],
  }
}
