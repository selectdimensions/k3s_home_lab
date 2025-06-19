# puppet/site-modules/profiles/manifests/k3s_agent.pp
# K3s agent profile for worker nodes
#
# @param server_url The URL of the K3s server to join
# @param token The K3s cluster token for authentication
# @param version The K3s version to install
class profiles::k3s_agent (
  String $server_url = 'https://pi-master:6443',
  String $token = '',
  String $version = 'v1.28.4+k3s1',
) {
  # Ensure base profile is applied first
  include profiles::base

  # Get values from hiera if defaults not overridden
  $actual_server_url = $server_url ? {
    'https://pi-master:6443' => lookup('pi_cluster::k3s::server_url', String, 'first', $server_url),
    default                  => $server_url,
  }

  $actual_token = $token ? {
    ''      => lookup('pi_cluster::k3s::token', String, 'first', $token),
    default => $token,
  }

  $actual_version = $version ? {
    'v1.28.4+k3s1' => lookup('pi_cluster::k3s::version', String, 'first', $version),
    default         => $version,
  }

  # Only install if we have the required parameters
  if $actual_token != '' and $actual_server_url != '' {
    # Install K3s agent
    exec { 'install_k3s_agent':
      command => epp('profiles/install_k3s_agent.sh.epp', {
          'version'    => $actual_version,
          'server_url' => $actual_server_url,
          'token'      => $actual_token,
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
