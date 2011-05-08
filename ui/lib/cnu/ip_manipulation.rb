

def ip(i)
  case i
  when String
   i.split('/')[0]
  when IpAddress
    i.to_s
#  when Fixnum,Bignum # one day
#    dec2ip(i)
  else
    raise Exception.new('fail')
  end
end

def gw(ip)
  case ip
  when String
   ip(ip).sub(/\.\d+$/,'.1')
  when IpAddress
    ip.gw() 
  else
    raise Exception.new('fail to find a gateway')
  end
end
def cidr_mask(ip)
  case ip
  when String
   ip.split('/')[1]
  when IpAddress
    ip.cidr() 
  else
    raise Exception.new('fail to find a netmask')
  end
end

def reverse_ip(ip)
  ip.split('.').reverse.join('.')
end

def is_ip?(str)
  str =~ /^(\d{1,3}\.){3}\d{1,3}/
end

require 'cnu'

module CNU::IpManipulation
def netmask(i)
   cidr = cidr_mask(i) 
   return '255.255.255.0' if cidr.nil?
   IPAddr.new('255.255.255.255').mask(cidr).to_s
end
#def last_octet(i)
#ip(i).split('.')[-2] + '.' +  ip(i).split('.')[-1]
#end

end


