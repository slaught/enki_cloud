require 'shoulda'
#include CNU::Gozer

class SanCmdRunnerTest < Test::Unit::TestCase

  context 'A SAN Command Runnner instance' do
    context 'with a 3par san' do
      setup do
        @san = '3par'
      end
      should 'create a 3par instance' do
        assert_instance_of CNU::Gozer::SanTypes::ThreePar,
                           CNU::Gozer::SanCmdRunner.new(@san).san
      end
    end
    context 'with an Equallogic san' do
      setup do
        @san = 'equallogic'
      end
      should 'create an Equallogic instance' do
        assert_instance_of CNU::Gozer::SanTypes::EqualLogic,
                           CNU::Gozer::SanCmdRunner.new(@san).san
      end
    end
  end

  context "A 3par san instance" do
    setup do
      @san = CNU::Gozer::SanTypes::ThreePar.new
    end

    should "create host" do
      assert_raise(Exception) do
        assert_match %r{createhost -iscsi -domain Enova -persona 1 -f testhost .*},
                   @san.create_host('Enova', 'testhost')
      end
      assert_match %r{createhost -iscsi -domain Enova -persona 1 -f testhost.dc .*},
                   @san.create_host('Enova', 'testhost.dc')
    end

    should "set_host" do
      assert_equal 'sethost -os {Debian Lenny} -loc {obr} -ip 127.0.0.1 postgres04',
                   @san.set_host('Debian Lenny', 'obr', '127.0.0.1', 'postgres04')
    end

    should "manage vluns" do
      assert_equal('createvlun VolumeToCreate 4 HostnameForVolume',
                   @san.vlun_mgmt(:create, 'VolumeToCreate', '4', 'HostnameForVolume'))
      assert_equal('removevlun -f VolumeToRemove 4 HostnameOfVolume',
                   @san.vlun_mgmt(:remove, 'VolumeToRemove', '4', 'HostnameOfVolume'))
      assert_raise(CNU::Gozer::SanTypes::ThreePar::BadAction) do
        @san.vlun_mgmt(:this_is_a_bad_action, 'Volume', 'Lun', 'Hostname')
      end
    end

    should "manage volumes" do
      assert_equal 'createvv -snp_cpg Prod-Snapshots Production VolumeToCreate 204800',
                   @san.create_volume("Prod-Snapshots", "Production", "VolumeToCreate", 204800)
      assert_equal 'removevv -f VolName',
                   @san.remove_volume('VolName')
    end

    should "manage snapshots" do
      assert_equal 'createsv -ro -comment {Comment} SnapshotName.ro VolName',
        @san.snap_mgmt(:ro, 'Comment', 'SnapshotName', 'VolName')
      assert_equal 'createsv -comment {Comment} SnapshotName.rw VolName.ro',
        @san.snap_mgmt(:rw, 'Comment', 'SnapshotName', 'VolName')
      assert_raise(CNU::Gozer::SanTypes::ThreePar::BadSnapshotType) do
        @san.snap_mgmt(:not_a_valid_type, 'Comment', 'SnapshotName', 'VolName')
      end
    end
  end
end

