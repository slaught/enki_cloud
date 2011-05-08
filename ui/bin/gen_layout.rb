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
# RAILS_DEFAULT_LOGGER = Logger.new(STDOUT)


require 'cnu/enki/config_layout'
include CNU::Enki::ConfigLayout
include CNU::Conversion
include CNU::IpManipulation

require 'cnu/enki/asa_rules'

def usage()

  puts "gen_layout.rb [-test|-commit] [username]"
  puts "    -test generate files for examination"
  puts "    -commit save generated files "
end

#
# Fix slow queries:
##script/plugin install git://github.com/blythedunham/static_record_cache.git
# 

def run 
    dirs = ['ha.d','node','downpage','lvs','uuid','xen','dns','space','asa','scs','nagios', 
            'haview.docroot','ssh', 'postgres', 'cdn']

    puts "Loading #{ENV['RAILS_ENV']} environment (Rails #{Rails.version})"

    t = Time.now() 
    lockfile_start()
    reset_git_repo()

    rmtree(dirs)
    create_dir(dirs)
    create_node_structure('node')

    # Query Caching Turned on for whole run
    ActiveRecord::Base.cache do
    
    # load balancer config
    ruby("gen_heartbeat")
    #puts "NOTICE:#{' '*29}ignore lines with 'We do not have quorum'" 
    #puts `ptest -VVV -X ha.d/heartbeat_constraints_cfg.xml`
    #puts `ptest -VVV -X ha.d/heartbeat_resources_cfg.xml`
    
    # TODO: add 'pacemaker' file checking
    puts "Checking pacemaker configs...."
    puts `#{Pathname.new($0).dirname}/validate-pacemaker-config -r ha.d/pacemaker_resources_cfg.xml -c ha.d/pacemaker_constraints_cfg.xml`

    ruby("gen_stonith_cfg")
    ruby("gen_lbstatus_config")

    ruby("gen_ldirectord_cfg")
    ldirectord_check = Pathname.new($0).dirname.join('ldirectord_check').realpath
    check_ldirectord("lvs/ldirectord*",ldirectord_check)
    ruby("gen_lb_downpage_config")

    # Surealived config
    CNU::Enki::Surealived.generate('surealived', 'lvs')
    
    # CDN nginx configs
    CNU::Enki::Cdn.generate('cdn', 'cdn')
    
    # lb.services to all load?.* nodes
    ruby("gen_lvs_cfg")
    move_match('lb.services','load?.*')

    # dns config
    ruby("gen_private_dns")
    
    # space config
    ruby("gen_space_yml")
    
    # uuid for bootstrap 
    ruby("gen_uuid")
    
    # domU configs for xen
    ruby("gen_domU_cfg")

    # serial console
    CNU::Enki::Scs.generate('scs')

    # nagios
    CNU::Enki::Nagios.generate('nagios')
    
    # Firewall
    CNU::Enki::AsaRules.generate('fw.acls','asa')

    # San DNS
    CNU::Enki::SanDns.generate('san_dns','dns')

    # Mgmt DNS
    CNU::Enki::MgmtDns.generate('mgmt_dns','dns')

    # SSH Known host list candidates
    CNU::Enki::SshKnownHosts.generate('ssh')

    # LB Page 
    CNU::Enki::LbPage.generate('haview.docroot')

    # Postgres Cluster configs
    CNU::Enki::DatabaseConfigs.generate('postgres')

    # per node configs
    FileUtils.chdir('node')
      ruby("gen_interface_cfg")
      ruby("gen_net_cfg")
      ruby("gen_udev_net_rules")
      ruby("gen_service_checks")

      CNU::Enki::ServiceChecks.generate('service.checks.v2')
      #PDU Labels
      CNU::Enki::PduLabels.generate('pdu.cfg')
      CNU::Enki::HpSwitchLabels.generate('switch.cfg')
      CNU::Enki::Iscsi.generate()
    FileUtils.chdir('..')

    end # end caching
    
    generate_md5sums('config_layout.md5', dirs)
    %x{find . -type d -print0 |xargs -0 chmod 755}
    %x{find . -type f -print0 |xargs -0 chmod 644}

    rc = 0 
    if ARGV.member?('-commit') then
      puts commit_files(dirs, :files => ['.dirs','config_layout.md5'], :dry_run => ARGV.member?('-test') ) 
    else 
      write_commit_message()
      puts "*" * 72
      puts "\nRemember to re-run with -commit flag to save configs for push\n\n"
      puts "*" * 72
      rc = 1
    end
    print_runtime(t,'Total') 

    return rc
end

def main
  begin
    otherargs = ARGV.reject {|x| ["-test","-commit"].member? x }
    if otherargs.length > 0  then
      usage()
      return 9
    end
    unless Pathname.new('.').realpath.basename.to_s =~ /^base_config_layout$/ then
      puts 'Error Not inside "base_config_layout" directory'
      return 2
    end
    trap("INT") { exit(-2) }
    run
  rescue Object => e
    puts "Error: #{e}"
    puts e.backtrace 
    return -1
  end
end
exit main()
__END__

git clone base_config_layout -> push_config_layout
git pull
git log ^#label
git label -a 'last_push'

# haskell:output9> echo node/load* | xargs -n 1 cp lb.services
#network_nodes.rb
CMD="ruby -I$P"
$CMD ./$P/gen_dir.rb
$CMD ./$P/gen_interface_cfg.rb
$CMD ./$P/gen_net_cfg.rb
$CMD ./$P/gen_udev_net_rules.rb
#######################################################################################
#
# generate the layout
# each node type has a specific file layout
# each machine warsync cluster has another manifest
#
#
# load1.dc1/cnu/etc/configs/node/lb.services
# load1.dc1/cnu/etc/configs/node/net.services
# lb link /etc/cnu/configs/apache2/sites-enabled/downpage-us_backend-apache.conf
# lb /data/downpage/<cluster>/downpage-<cluster>-apache.conf
# lb /etc/cnu/configs/ha.d/heartbeat_constraints_cfg.xml
# lb /etc/cnu/configs/ha.d/heartbeat_resources_cfg.xml
# lb /etc/cnu/configs/ha.d/lb_heartbeat_stonith.cfg
# lb /etc/cnu/configs/ha.d/lbstatus-lvs_clusters
# lb /etc/cnu/configs/ha.d/lbstatus-lvs_nodes
# lb /etc/cnu/configs/lvs/ldirectord_us_backend.cfg

# 
# virtual /etc/cnu/configs/node/net.services

# physical
# p /etc/cnu/configs/node/net.services
# p /etc/cnu/configs/node/net.services
# p /etc/cnu/configs/node/interfaces  
# p /etc/cnu/configs/node/net.services 
# p /etc/cnu/configs/node/udev.rules 
# p /etc/cnu/configs/node/<hostname.loc>/[files...]
#

## UUID for bootstrap
# uuid/
# symlinks to node setup

##### Xen domU configs
#rsync --delete -v -a ${SRC}/node/xen* xen01.dc1:local/xen_node_configs
#rsync --delete -v -a ${SRC}/xen/xen01.dc1:local/xen
#  SRC=local
#  #find $SRC -type d |xargs chmod 755
#  #find $SRC -type f |xargs chmod 644
#  sudo rsync -v -a ${SRC}/xen_node_configs/ /etc/cnu/configs/node
#  sudo rsync -v -a ${SRC}/xen/ /etc/cnu/configs/xen
#config_base/
#            node/<node>/lb.services
#            node/<node>/net.services
#            node/<node>/interfaces
#            downpage/<cluster>/downpage-<cluster>-apache.conf
#            ha.d/*
#            lvs/ldirectord_*.cfg
#
