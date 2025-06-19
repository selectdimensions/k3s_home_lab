# puppet/site-modules/profiles/manifests/base/windows.pp
# Windows-specific base configuration
class profiles::base::windows {
  # Windows Update configuration
  class { 'windows_updates':
    ensure => 'enabled',
    day    => 'Sunday',
    time   => '03:00',
  }

  # Essential Windows packages via Chocolatey
  include chocolatey

  $windows_packages = [
    'git',
    'vscode',
    'powershell-core',
    'kubernetes-cli',
    'helm',
  ]

  package { $windows_packages:
    ensure   => present,
    provider => 'chocolatey',
  }

  # Configure Windows Defender exclusions
  windows_defender_exclusion { 'C:\k':
    ensure => present,
    type   => 'folder',
  }
}
