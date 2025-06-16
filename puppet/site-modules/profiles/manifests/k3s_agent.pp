# K3s agent profile for worker nodes
class profiles::k3s_agent (
  String $server_url,
  String $token,
  String $version = lookup('pi_cluster::k3s::version'),
) {
  
  # Install K3s agent
  exec { 'install_k3s_agent':
    command => @("CMD"/L),
      curl -sfL https://get.k3s.io | \
      INSTALL_K3S_VERSION=${version} \
      K3S_URL=${server_url} \
      K3S_TOKEN=${token} \
      sh -s - agent \
      --node-name ${facts['networking']['hostname']}
      | CMD
    path    => ['/usr/bin', '/usr/local/bin'],
    creates => '/usr/local/bin/k3s',
  }
  
  # Ensure K3s agent service is running
  service { 'k3s-agent':
    ensure  => running,
    enable  => true,
    require => Exec['install_k3s_agent'],
  }
}
