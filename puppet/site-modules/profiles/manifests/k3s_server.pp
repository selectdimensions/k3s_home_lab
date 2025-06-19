# puppet/site-modules/profiles/manifests/k3s_server.pp
# K3s server profile
#
# @param version The K3s version to install
# @param disable_components Array of K3s components to disable
class profiles::k3s_server (
  String $version = 'v1.28.4+k3s1',
  Array[String] $disable_components = ['traefik', 'servicelb'],
) {
  # Get values from hiera if defaults not overridden
  $actual_version = $version ? {
    'v1.28.4+k3s1' => lookup('pi_cluster::k3s::version', String, 'first', $version),
    default         => $version,
  }

  $actual_disable_components = $disable_components == ['traefik', 'servicelb'] ? {
    true    => lookup('pi_cluster::k3s::disable_components', Array[String], 'first', $disable_components),
    default => $disable_components,
  }

  # Install K3s server
  exec { 'install_k3s_server':
    command => epp('profiles/install_k3s_server.sh.epp', {
        'version'            => $actual_version,
        'disable_components' => $actual_disable_components,
        'hostname'           => $facts['networking']['hostname'],
    }),
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
