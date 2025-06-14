# K3s server profile
class profiles::k3s_server (
  String $version = lookup('pi_cluster::k3s::version'),
  Array[String] $disable_components = lookup('pi_cluster::k3s::disable_components'),
) {
  
  # Install K3s server
  exec { 'install_k3s_server':
    command => @("CMD"/L),
      curl -sfL https://get.k3s.io | \
      INSTALL_K3S_VERSION=${version} \
      sh -s - server \
      --write-kubeconfig-mode 644 \
      --disable ${disable_components.join(' --disable ')} \
      --node-name ${facts['networking']['hostname']}
      | CMD
    path    => ['/usr/bin', '/usr/local/bin'],
    creates => '/usr/local/bin/k3s',
  }
  
  # Ensure K3s service is running
  service { 'k3s':
    ensure  => running,
    enable  => true,
    require => Exec['install_k3s_server'],
  }
  
  # Export node token for workers
  file { '/etc/rancher/k3s/node-token':
    ensure  => file,
    mode    => '0640',
    require => Service['k3s'],
  }
  
  # Configure kubectl for local use
  file { '/root/.kube':
    ensure => directory,
  }
  
  file { '/root/.kube/config':
    ensure  => link,
    target  => '/etc/rancher/k3s/k3s.yaml',
    require => [File['/root/.kube'], Service['k3s']],
  }
}