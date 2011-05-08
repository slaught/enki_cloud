
require File.dirname(__FILE__) + '/../test_helper'

require 'test/unit'
require 'network_nodes'

require 'cnu/enki/config_layout'

class HelperTest < Test::Unit::TestCase
  include CNU::Enki::ConfigLayout
  include CNU::Conversion 

  def setup
  end

  def test_now
    s = now()
    assert_match /\w\w\w \d{1,2}, \d{4} \d{1,2}:\d{1,2}:\d{1,2}/, s
  end
  #  DateTime.now().strftime('%h %d, %Y %H:%M:%S')
  def test_ip2hex
    x = ip2hex('255.255.255.255')
    assert_not_nil x
    assert_equal String, x.class 
    assert_equal 8,  x.length
    assert_equal 'f' * 8, x
  end
  def test_hex2ip
    x = hex2ip('FFFFFFFF') 
    assert_equal String, x.class 
    assert_equal '255.255.255.255', x
  end 
  def test_dec2hex
    d = 45676
    assert_equal "%.8x" % d, dec2hex(d)
  end
  def test_hex2dec
    h = 'ff'
    assert_equal h.hex, hex2dec(h)
  end

  def test_converters
    s = 'ffefbc56'
    ip = '207.56.254.81'
    h = '000000fe'
    d = 4565
    assert_equal s, ip2hex(hex2ip(s))
    assert_equal ip,  hex2ip(ip2hex(ip)) 
    assert_equal h, dec2hex(hex2dec(h))
    assert_equal d, hex2dec(dec2hex(d))
    assert_equal ip2hex(ip), ip2hex(dec2ip(ip2dec(ip))) 
  end

  def test_outputfn
    p = '1234asdf'
    s = '.test.delete.me'
    x = output_fn(p,s)
    assert_match /^#{p}/, x
    assert_match %r{#{s}$}, x
    #
    # how the function works is why this test works. 
    assert_equal "/#{s}", output_fn('/',s)
  end

  def test_macaddr
    macs = ['00:2a:9b:a6:19:85', '00:21:9b:b6:19:85', '00:21:9b:a6:19:85']
    macs_sorted = macs.sort{|mac1, mac2| MacAddr.new(mac1) <=> MacAddr.new(mac2)}
    assert_equal macs.reverse, macs_sorted
  end
end
