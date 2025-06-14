require 'spec_helper'

describe 'profiles::k3s_server' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:params) do
        {
          version: 'v1.28.4+k3s1',
          disable_components: ['traefik', 'servicelb']
        }
      end

      it { is_expected.to compile }

      it { is_expected.to contain_exec('install_k3s_server')
        .with_command(/INSTALL_K3S_VERSION=v1.28.4\+k3s1/)
        .with_creates('/usr/local/bin/k3s')
      }

      it { is_expected.to contain_service('k3s')
        .with_ensure('running')
        .with_enable(true)
      }

      it { is_expected.to contain_file('/root/.kube/config')
        .with_ensure('link')
        .with_target('/etc/rancher/k3s/k3s.yaml')
      }
    end
  end
end