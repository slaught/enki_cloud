ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'

require 'authenticated_test_helper'
require File.expand_path(File.dirname(__FILE__) + "/blueprints")

class ActiveSupport::TestCase
  # Transactional fixtures accelerate your tests by wrapping each test method
  # in a transaction that's rolled back on completion.  This ensures that the
  # test database remains unchanged so your fixtures don't have to be reloaded
  # between every test method.  Fewer database queries means faster tests.
  #
  # Read Mike Clark's excellent walkthrough at
  #   http://clarkware.com/cgi/blosxom/2005/10/24#Rails10FastTesting
  #
  # Every Active Record database supports transactions except MyISAM tables
  # in MySQL.  Turn off transactional fixtures in this case; however, if you
  # don't care one way or the other, switching from MyISAM to InnoDB tables
  # is recommended.
  self.use_transactional_fixtures = true 

  # Instantiated fixtures are slow, but give you @david where otherwise you
  # would need people(:david).  If you don't want to migrate your existing
  # test cases which use the @david style and don't mind the speed hit (each
  # instantiated fixtures translates to a database query per test method),
  # then set this back to true.
  self.use_instantiated_fixtures  = false

  # Add more helper methods to be used by all tests here...
  #
  include AuthenticatedTestHelper
  setup { Sham.reset }

  def make_admin_user
    _make_user_with_role('admin','admiraladmin')
  end
  def make_dba_user
    _make_user_with_role('dba')
  end
  def make_eng_user
    _make_user_with_role('engineer')
  end
  def make_rampart_admin_user
    _make_user_with_role('rampart_admin')
  end
# create a sysadmin user with nav_admin overlay auth
  def make_nav_admin_user
    u = _make_user_with_role('sysadmin') 
    u.roles << Role.find_by_name('nav_admin')
    u
  end
  def _make_user_with_role(role, login=nil)
    if login
      u = User.find_by_login(login)
      if u.nil?
        u = User.make(:login => login) if u.nil?
      end
    else
      u = User.make
    end
    r = Role.find_by_name(role)
    # UserRole.make(user => u, role => r ) 
    unless u.roles.exists? r
      u.roles << r
    end
    u
  end
  def make_san_node
    n = Node.make(:physical)
    n.nics << Nic.make(:san)
    n.nics << Nic.make(:san)
    n
  end
  def make_active_cluster(load_balanced=true)
    c = Cluster.make
    s = Service.make(:local_port => nil)
    c.services << s
    s = Service.make
    c.services << s
    n = make_proper_node :virtual
    c.add_node(n)
    n = make_proper_node :virtual
    c.add_node(n)
    c
  end
  def make_db_cluster(hash={})
     s = Service.make
     config = DatabaseConfig.make
     DatabaseCluster.make(hash.merge({:service => s, :database_config => config})  )
  end
  # DEPRECATED: call make_proper_node(*args) instead!
  def create_node_by_controller(*args)
    make_proper_node(*args)
  end
end


class ActionController::TestCase
  include AuthenticatedTestHelper
  include Authorization::TestHelper

  def assert_redirect(options={}, message =nil)
      assert_response(:redirect, message)
      return true if options == @response.redirected_to
    u = @controller.url_for options.merge( :only_path => true )
    assert @response.redirect_url_match?( /#{u}/ )
  end
  def assert_successful_render(options={}, message=nil)
    assert_response :success
    assert_no_match /TemplateError/, @response.body
  end
end

class ActionController::IntegrationTest
  # Only require gem when libnokogiri has been installed and nothing breaks
  begin
    require 'capybara/rails'
  rescue Exception=>e
    setup { puts "ERROR: Couldn't require Capybara! ALL CAPYBARA TESTS WILL FAIL.
        (Are you sure libnokogiri is installed?)" }
  else
    include AuthenticatedTestHelper
    include Authorization::TestHelper

    Capybara.ignore_hidden_elements = false

    def has_selected_option?(value)
      Capybara::has_xpath?("//option[@selected='selected' and contains(string(), #{value})]")
    end
    def has_option?(select_box, option_value)
      Capybara::find_field(select_box).find("//option[.='#{option_value}']")
    end
    def rendered_sanely?
      Capybara::has_link? 'IT CFG Database'
    end
    def click_button_titled(title)
      Capybara::find("//input[@title='#{title}'][1]").click
    end
  end
end

class NetworkNodeTest < ActiveSupport::TestCase
  def test_basics
    assert ActiveRecord::Base.connection.active?, 'No Database connection'
  end
end

# create fake datacenters for more robust testing
def make_test_datacenters
  dc_names = ['lat', 'il', 'mi', 'nand', 'camp']
  dc_names.each{|dc| Datacenter.make :name => dc if not Datacenter.find_by_name(dc)}
end

make_test_datacenters
