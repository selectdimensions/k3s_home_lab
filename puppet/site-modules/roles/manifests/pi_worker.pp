# puppet/site-modules/roles/manifests/pi_worker.pp
# Role for Pi Worker Node
class roles::pi_worker {
  include profiles::base
  include profiles::networking
  include profiles::security
  include profiles::k3s_agent
  include profiles::monitoring_agent

  Class['profiles::base']
  -> Class['profiles::networking']
  -> Class['profiles::security']
  -> Class['profiles::k3s_agent']
  -> Class['profiles::monitoring_agent']
}
