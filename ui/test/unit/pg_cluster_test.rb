require 'test_helper'

class DatabaseVersionTest < ActiveSupport::TestCase
  def test_find_and_label
    test_ver = '8.4'
    ver = DatabaseVersion.find_by_version(test_ver)
    assert_not_nil ver
    assert_equal test_ver, ver.to_label
  end
end
class DatabaseNameTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  def test_create
    assert_not_nil DatabaseName.make
  end
  def test_association
    db = DatabaseName.make
    assert_equal [], db.database_clusters
  end
end    

class DatabaseClusterTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  def test_create
    assert_not_nil make_db_cluster # DatabaseCluster.make 
  end
  def error_msg(x)
    [ x].flatten.first
  end
  def test_fail
    d = DatabaseCluster.new(DatabaseCluster.plan)
    assert_not_nil d
    assert (not d.valid?)
    assert_equal "can't be blank", error_msg(d.errors.on('service')) 
    assert_equal "can't be blank", error_msg(d.errors.on('database_config'))
  end
  def test_associations
    c = make_db_cluster
    dn = DatabaseName.make
    assert_not_nil c
    assert_not_nil dn
    assert ( c.database_names << dn ) 
    assert_equal 1, c.database_names.length
    assert dn.reload
    assert_equal 1, dn.database_clusters.length
    assert_equal c, dn.database_clusters.first
    assert_equal dn,  c.database_names.first 
  end
end
