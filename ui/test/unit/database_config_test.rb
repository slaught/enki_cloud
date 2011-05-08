require 'test_helper'

class DatabaseConfigTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  def test_truth
    assert true
  end
  def test_config
    x = DatabaseConfig.make
    assert_not_nil x
    assert_not_nil x.format_search_path
  end
end
