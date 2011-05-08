
require File.dirname(__FILE__) + '/../test_helper'

require 'network_nodes'

class NicTest < NetworkNodeTest
#  fixtures  :nics
  def test_udev_rule
    Nic.make
    nic = Nic.find(:first)
    assert_not_nil nic
    u = nic.udev_rule
    assert_match  %r(#{nic.mac_address.downcase.strip()}), u
    assert_match  %r(#{nic.port_name.downcase.strip()}), u
    assert_match  %r(#{nic.port_name.downcase.strip()}), u
    assert_match %r(SUBSYSTEM=="net",), u
    assert_match %r(SUBSYSTEM=="net", ACTION=="add", DRIVERS=="\?\*",), u 
    assert_match %r/ATTR.address.=="([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}/, u
    assert_match %r(KERNEL=="eth\*",), u
    assert_match %r/^SUBSYSTEM=="net", ACTION=="add", DRIVERS=="\?\*", ATTR\{address\}==".{17}", ATTR\{type\}=="1", KERNEL=="eth\*", NAME=".+"$/, u
    assert_match %r/NAME="\w+"/, u
  end
end

