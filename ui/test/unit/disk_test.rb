require 'test_helper'

class DiskTest < ActiveSupport::TestCase
  def test_create
    disk = Disk.make :iscsi
    assert_not_nil disk
  end
end
