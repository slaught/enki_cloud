require 'test_helper'

class NetworkTest < ActiveSupport::TestCase

  def test_create
    assert_not_nil NodeType.find(:first)
  end
  def test_router_type
    x =  NodeType.create(:node_type => 'router')
    assert_not_nil x, 'created ok'
    assert x.is_router?, 'is a router'
    assert x.can_has_pdu?, 'can have a pdu'
    assert x.can_has_serial_console?, 'can have a scs'
    assert x.can_has_switch_port?, 'can have a switch port'
  end

end
