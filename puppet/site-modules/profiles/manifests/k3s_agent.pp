# puppet/site-modules/profiles/manifests/k3s_agent.pp
# K3s agent profile for worker nodes
#
# @param server_url The URL of the K3s server to join
# @param token The K3s cluster token for authentication
# @param version The K3s version to install
class profiles::k3s_agent (
  String $server_url = lookup('pi_cluster::k3s::server_url', String, 'first', 'https://pi-master:6443'),
  String $token = lookup('pi_cluster::k3s::token', String, 'first', ''),
  String $version = lookup('pi_cluster::k3s::version', String, 'first', 'v1.28.4+k3s1'),
) {
  # Ensure base profile is applied first
  include profiles::base

  # Only install if we have the required parameters
  if $token != '' and $server_url != '' {
    # Install K3s agent
    exec { 'install_k3s_agent':
      command => epp('profiles/install_k3s_agent.sh.epp', {
          'version'    => $version,
          'server_url' => $server_url,
          'token'      => $token,
          'hostname'   => $facts['networking']['hostname'],
      }),
      path    => ['/usr/bin', '/usr/local/bin', '/bin'],
      creates => '/usr/local/bin/k3s',
      timeout => 300,
    }

    # Ensure K3s agent service is running
    service { 'k3s-agent':
      ensure  => running,
      enable  => true,
      require => Exec['install_k3s_agent'],
    }
  } else {
    notify { 'k3s_agent_config_missing':
      message => 'K3s agent not configured - missing token or server_url',
    }
  }
}
