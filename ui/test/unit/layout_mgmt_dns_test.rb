require 'test_helper'

class LayoutMgmtDnsTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  include CNU::IpManipulation
  def test_reverse_ip
    x = '1.1.1.1'
    y = reverse_ip(x)
    assert_equal x,y
    assert_equal '4.3.2.1',reverse_ip('1.2.3.4.')
  end
end
