# puppet/site-modules/profiles/manifests/base/darwin.pp
# macOS-specific base configuration
class profiles::base::darwin {
  # Homebrew package management
  include homebrew

  $mac_packages = [
    'kubectl',
    'helm',
    'k9s',
    'stern',
    'jq',
    'yq',
  ]

  package { $mac_packages:
    ensure   => present,
    provider => 'homebrew',
  }

  # Configure macOS firewall
  exec { 'enable_firewall':
    command => '/usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on',
    unless  => '/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate | grep "enabled"',
  }
}
