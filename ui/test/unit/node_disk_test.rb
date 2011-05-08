require 'test_helper'

def assert_compare(left_block, operator, right_block)
  left_node_disk = NodeDisk.make :block_name => left_block
  right_node_disk = NodeDisk.make :block_name => right_block
  assert_operator left_node_disk, operator, right_node_disk
end

class NodeDiskTest < ActiveSupport::TestCase
  def test_less_than
    assert_compare('sda7', '<', 'sda15')
  end
  def test_equal
    assert_compare('sdb', '==', 'sdb')
  end
  def test_more_than
    assert_compare('sda15', '>', 'sda7')
  end

  def test_duplicate_block_name
    node = Node.make :virtual
    node_disk_1 = NodeDisk.make :node => node, :block_name => 'sda'
    node_disk_2 = NodeDisk.new(:node => node, :block_name => 'sda', :disk => Disk.make(:file))
    assert_equal false, node_disk_2.valid?
  end
end
