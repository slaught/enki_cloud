#!/usr/bin/ruby

require 'pathname'

# when in a bin or script dir
$:.unshift(Pathname.new($0).realpath.dirname.join('../lib').realpath)
#$:.unshift(Pathname.new($0).realpath.dirname.join('../app/models').realpath)
$:.unshift(Pathname.new($0).realpath.dirname.join('..').realpath)
$:.unshift(Pathname.new($0).realpath.dirname.realpath)

$verbose = false
ENV['RAILS_ENV'] = 'production' if ENV['RAILS_ENV'].nil?

require 'config/environment'

def usage()
  puts "versions_changelog.rb [-v] [version]"
  puts "  -v provides current version number"
end
def describe_item(v)
  case v.item_type 
  when "Node", "Cluster", "Service", "San", "CnuMachineModel"
    if v.item.blank?
      "#{v.item_type}"
    else
      "#{v.item_type}: #{v.item.to_label}"
    end
  when ClusterService
      " service in cluster "
  when ClusterNode
      " node in cluster "
  when Nic
    if v.item.blank?
      "#{v.item_type}"
    else
      "#{v.item_type} mac #{v.item.mac_address}"
    end
  else
    v.item_type
  end
  
end

def changelog(v1)
  puts "Changelog between version #{v1} and #{Version.last.id} (current)\n"
  cl_versions = Version.find(:all, :conditions => ["id >= ?", v1.to_i])

  mstr_output = cl_versions.map do |v| 
    output = []
    output << "Date: #{v.created_at}  Version: #{v.id}\n"
    output << "#{v.event}: #{describe_item(v)}"
    if v.whodunnit.to_i > 0
      output << " by #{User.find(v.whodunnit.to_i).name}\n"
    else
      output << " by #{v.whodunnit}\n"
    end
    output.flatten.join("")
  end

  puts mstr_output.join("")
end

def main()
  if ARGV.length < 1
    usage()
    return 2
  end

  if ARGV[0] == "-v"
    puts "Current version: #{Version.last.id}"
  else
    changelog(ARGV[0])
  end
end

main()
__END__

