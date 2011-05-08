require 'test_helper'

class JavascriptTest < ActionController::IntegrationTest
  Capybara.default_driver = :selenium
  ActiveSupport::TestCase.use_transactional_fixtures = false

  def setup 
    # clear static caches because their IDs will change during each test.
    # make sure to add corresponding lines here when there are new cached models!
    NetworkType.clear_static_record_cache
    Datacenter.clear_static_record_cache
    NodeType.clear_static_record_cache
    Protocol.clear_static_record_cache
  end
  def teardown
    db = Rails::Configuration.new.database_configuration['test']['database']
    %x[psql -c 'select truncate_tables();' #{db}]
    %x[psql -f #{RAILS_ROOT}/db/seed_data.sql #{db}]
    if File.exist?("#{RAILS_ROOT}/db/seed_data_private.sql")
       %x[psql -f #{RAILS_ROOT}/db/seed_data_private.sql #{db}]
    end
    make_test_datacenters
  end

  # call this for every test with a JS popup confirmation dialog, at a point BEFORE the dialog appears
  def disable_confirmation_dialogs
    Capybara::page.execute_script('window.confirm = function() { return true }')
  end
  # wrapper to counteract the annoying "Element No longer attached to DOM" error
  def ajax_safe
    begin
      yield
    rescue Selenium::WebDriver::Error::ObsoleteElementError
      retry
    end
  end
  def has_visible_content?(content)
    finder_script = %{ 
      $j = jQuery.noConflict();   // '$' defaults to prototype. Using $j for jQuery...
        function is_text_visible_on_page(text) { 
          var match = false; 
          $j('*:visible') 
            .contents() 
            .filter(function() { 
              //collect text nodes 
              return this.nodeType === 3; 
            }) 
            .each(function() { 
              if (this.textContent.indexOf(text) != -1) { 
                match = true; 
                return false; 
              } 
            }); 
          return match; 
        } 
        is_text_visible_on_page('#{content}'); 
      }
    page.driver.evaluate_script(finder_script)
  end
  def has_no_visible_content?(content)
    ! has_visible_content?(content)
  end
end
