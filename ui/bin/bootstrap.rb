#!/usr/bin/ruby
#
# Dependencies: cat dmesg dmidecode
#
# FIXME: enova facts
DASBOOT_URL_TEST = 'http://localhost:8000/bootstraps'
DASBOOT_URL = 'http://somewhere.example.com:8000/bootstraps'

require 'net/http'
require 'uri'

def	check_network_ready_for_node(url)
  debug("Ready? #{url}")
 	while true
		status = get url
		if status.code == '200' then
			return reboot
		else
			wait_to_try_again 
		end
	end
end
def wait_to_try_again 
  if @debug
    sleep 5
  else
  	puts 'sleeping for a minute'
    sleep 60
  end
end
def reboot
	return
end

def what_stage_am_i?(args)
  args.select { |a| a !~ /^-.+/ }.first
end
def main
  if ARGV.member? '-debug' then
    @debug = true 
    boot_url =  DASBOOT_URL_TEST
  else
    @debug = false
    boot_url =  DASBOOT_URL
  end
  stage = what_stage_am_i?(ARGV)

	mech_data = collect_machine_data
	puts "Got #{mech_data.keys().join(', ')}" if @debug
	cookie = nil #get_cookie(DASBOOT_URL)
	begin
		post_data(boot_url, mech_data, cookie)
	rescue Exception => e
		puts e
	end
	uuid = mech_data['uuid_tag'] 
	check_network_ready_for_node boot_url + "/ready#{stage}/#{uuid}"
end
def get_uuid(dmidecode_data)
#  UUID: 44454C4C-3300-1043-8035-B9C04F344431
	dmidecode_data =~ /UUID: ([-\w]+)\s*$/
	$1
end
def get_service_tag(dmidecode_data)
#          Serial Number: B7JNVH1
	dmidecode_data =~ /Serial Number: ([\w]+)\s*$/
	$1
end
def get_dmidecode_data(dmidecode_data, regex)
	dmidecode_data =~ regex
	$1
end
def collect_machine_data
	a = [ 
		procfile( "cpuinfo") ,
		prog( "dmesg" ),
		prog("dmidecode"),
		procfile('meminfo'),
    prog('ip -o link') 
		]
	h = Hash[ *a.flatten ]
  dmidecode = h['dmidecode']
	h['uuid_tag'] = get_uuid h['dmidecode']
  puts h['uuid_tag'] 
	h['service_tag'] = get_service_tag dmidecode
  h['product_name'] = get_dmidecode_data(dmidecode, /Product Name: ([\w\s]*[\w])\s*$/)

  if false and  @debug then
	  h['dmesg'] = 'dmesg' 
  	h['dmidecode'] = 'dcode' 
	  puts h.inspect 
  end
	h
end
def procfile(n)
	[ "proc_#{n}" , %x{cat /proc/#{n} } ]
end
def prog(exe)
	[ exe.split.first , `#{exe}` ]
end

def parse_cookie(response)
	data = response.response['set-cookie'].split(';')
	data[0]
end
def get_cookie(base_url)
	url = URI.parse(base_url)
	req = Net::HTTP::Get.new(url.path)
	req.add_field('Accept','text/xml')
	res = Net::HTTP.new(url.host, url.port).start {|http|
		res = http.request(req)
		debug(res.response.inspect) 
		case res
			when Net::HTTPSuccess, Net::HTTPRedirection
			cookie = parse_cookie(res)
		else
			puts res.error!
		end
		cookie
	}
end
def post_data(form_url, data, cookie=nil)
	url = URI.parse(form_url)
	req = Net::HTTP::Post.new(url.path)
	req.add_field('Accept','text/xml')
	req.set_form_data(data)
	req['Cookie'] = cookie
	res = Net::HTTP.new(url.host, url.port).start {|http|
		http.request(req)
	}
	case res
	when Net::HTTPSuccess, Net::HTTPRedirection
		res
	else
		puts res.error!
		puts res.inspect
		puts res.to_s
		nil
	end
end
def get(base_url)
	url = URI.parse(base_url)
	req = Net::HTTP::Get.new(url.path)
	req.add_field('Accept','text/html')
	http = Net::HTTP.new(url.host, url.port)
	#http.use_ssl = true if url.port > 80
    #http.verify_mode = OpenSSL::SSL::VERIFY_NONE
	  res = http.start {|http|
		res = http.request(req)
		#puts res.response.inspect
		case res
		when Net::HTTPSuccess, Net::HTTPRedirection, Net::HTTPNotFound
			res	
		else
      puts res.inspect
      puts res
			raise Exception.new('Bad return code' + res.error!)
		end
	}
	res
end

def debug(*s)
	if @debug then
		puts s
	end
end

main()
