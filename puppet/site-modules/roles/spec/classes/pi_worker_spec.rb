# puppet/site-modules/roles/spec/classes/pi_worker_spec.rb
# frozen_string_literal: true

require 'spec_helper'

describe 'roles::pi_worker' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it { is_expected.to contain_class('profiles::base') }
      it { is_expected.to contain_class('profiles::networking') }
      it { is_expected.to contain_class('profiles::security') }
      it { is_expected.to contain_class('profiles::k3s_agent') }
      it { is_expected.to contain_class('profiles::monitoring_agent') }
    end
  end
end
