# puppet/site-modules/profiles/spec/classes/base_spec.rb
require 'spec_helper'

describe 'profiles::base' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it { is_expected.to contain_exec('apt_update') }

      it { is_expected.to contain_package('curl').with_ensure('present') }
      it { is_expected.to contain_package('wget').with_ensure('present') }
      it { is_expected.to contain_package('git').with_ensure('present') }

      it { is_expected.to contain_exec('enable_cgroups') }
      it { is_expected.to contain_service('dphys-swapfile').with_ensure('stopped') }
    end
  end
end
