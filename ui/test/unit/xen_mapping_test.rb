require 'test_helper'

class XenMappingTest < ActiveSupport::TestCase
  def test_create 
    v = Node.make(:virtual)
    p = Node.make(:physical)
    x = XenMapping.add_guest(p,v)
    assert_not_nil x , 'create mapping'
  end
  def test_move_guest
    v = Node.make(:virtual)
    p1 = Node.make(:physical)
    p2 = Node.make(:physical)
    assert XenMapping.add_guest(p1,v)
    assert_raise (ActiveRecord::StatementInvalid) {
      x = XenMapping.add_guest(p2,v)
    }
    assert XenMapping.move_guest(p2,v), 'move test'
    assert XenMapping.remove_guest(v), 'remove once succeed'
    assert XenMapping.remove_guest(v), 'remove non-existent'
  end
  def test_fail_guest
    v = Node.make(:virtual)
    p = Node.make(:physical)
    assert_raise (Exception) {
      x = XenMapping.add_guest(v,p)
    }
    assert_raise (Exception) {
      x = XenMapping.add_guest(p,p)
    }
    assert_raise (Exception) {
      x = XenMapping.add_guest(v,v)
    }
  end
  def test_unassigned
    v1 = Node.make(:virtual)
    v2 = Node.make(:virtual)
    p = Node.make(:physical)
    unassigned = XenMapping.unassigned()
    assert_not_nil unassigned
    assert_operator unassigned.length, '>=', 2

    assert_difference 'unassigned.length', -1 do
      x = XenMapping.add_guest(p,v1)
      unassigned = XenMapping.unassigned()
      assert_not_nil unassigned
    end
    assert unassigned.first.class == Node
    u = unassigned.map {|n| n.datacenter }
    assert_operator u.length, '>=', 1
    assert u.first.class == Datacenter
    
  end
end
