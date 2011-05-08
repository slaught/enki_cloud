
require 'test_helper'

class SanTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  def test_create
    assert_not_nil San.make 
  end
  def test_add_node
    san = San.make
    assert_not_nil san
    n = make_san_node
    assert_not_nil n
    assert san.add_node(n)
    sanips = n.san_interfaces
    num_san_nics = n.san_nics.length
    assert_equal num_san_nics, san.nodes.length
    assert_equal num_san_nics , sanips.length
    # san_interfaces returns arry of 2 element arrays.
    assert_equal [2], sanips.map{|x| x.length}.uniq, 'check structure'
    ifaces = sanips.map{|x| x.first }
    assert_equal num_san_nics, ifaces.length
    ifaces.each {|iface|
      assert_match /^eth\d+$/, iface
    }
    ips = sanips.map{|x| x.second }
    assert_equal num_san_nics, ips.length
    ips.each {|iface|
      assert_match /^\d+\.\d+\.\d+\.\d+$/, iface
    }
# <[["eth3", "47.235.140.20"], ["eth5", "47.235.140.21"]]>.
 #   assert_equal [], n.sans.map{|x| x.ip_addresss_old }
  end
 def test_san_node
    n = make_san_node
   assert_not_nil n
   assert_equal 2, n.san_nics.length
   assert_equal [], n.san_interfaces, 'no san assignments'
  end
  def test_remove_node
    san = San.make
    assert_not_nil san
    n = make_san_node
    assert_not_nil n
    before_ips = IpAddress.count()
    assert before_ips >= 0
    before = SanNode.count(:conditions => {:san_id => san.id})
    assert_not_nil before
    assert san.add_node(n)
    assert san.nodes.length > before
#    assert_equal before_ips + n.san_nics.length, IpAddress.count(), 'two more
    assert_equal (before_ips + n.san_nics.length), IpAddress.count(), 'two more ips'
    assert san.remove_node(n)
    after_ips = IpAddress.count()
    after = SanNode.count(:conditions => {:san_id => san.id})
    assert_equal before, after , "check for removed san_nodes"
    assert_equal before_ips, after_ips,"check for removed ips"
  end
#  def test_fail
#    d = DatabaseCluster.new(DatabaseCluster.plan)
#    assert_not_nil d
#    assert (not d.valid?)
#    assert_equal "can't be blank", error_msg(d.errors.on('service')) 
#    assert_equal "can't be blank", error_msg(d.errors.on('database_config'))
#  end
#  def test_associations
#    c = make_db_cluster
#    dn = DatabaseName.make
#    assert_not_nil c
#    assert_not_nil dn
#    assert ( c.database_names << dn ) 
#    assert_equal 1, c.database_names.length
#    assert dn.reload
#    assert_equal 1, dn.database_clusters.length
#    assert_equal c, dn.database_clusters.first
#    assert_equal dn,  c.database_names.first 
#  end
end
