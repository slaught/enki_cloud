require 'test_helper'

class BootstrapTest < ActiveSupport::TestCase

  def setup
    @boot = Bootstrap.make
  end
  def test_truth
    assert @boot
  end
end
