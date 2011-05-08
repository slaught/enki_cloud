require 'cnu'

module CNU::Conversion

def ip2hex(ip)
  ip.split('.').map {|i| "%.2x" % i }.join()
end

def hex2ip(h)
    if h.length == 8 then
      "%d.%d.%d.%d" % ( h.scan(/[[:xdigit:]]{2,2}/).map {|x| x.to_i(16) } )
    else
      h
    end
end
def dec2hex(d)
  ("%.8x" % d)
end

def hex2dec(h)
  h.hex
end

# used by others
def dec2ip(d)
  hex2ip( dec2hex(d) )
end

# used by others
def ip2dec(ip)
   hex2dec ip2hex(ip)
end
end

