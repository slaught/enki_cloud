#!/usr/bin/ruby
#
#
require 'find'
require 'set'

TEMPLATE = 'debian/%s.install'
DIRS= ['bin','scripts']
INSTALL_PREFIX='enki/'

def dpkg_find(directories, excluded_files=[], &block)
  directories.map { |dir|
    f = []
    Find.find(dir) do |path|
      if File.basename(path) == 'debian' then
        Find.prune
      elsif File.basename(path) == '.git' then
        Find.prune
      elsif excluded_files.member? File.basename(path) then
        next
      elsif File.basename(path) =~ /^ruby_sess.*/ then
        next 
      else
        x = yield(path)
        f << x
      end
    end
    f.compact
  }.flatten.compact
end

def find_files(dirs)
  dpkg_find(dirs)  do |path|
    if Kernel.test('f', path) and not Kernel.test('l',path) then
      path
    else
      nil  
    end
  end
end

def ls_packages(control='debian/control')
  packages = nil
  File.open(control) do |io|
      x = io.readlines()
      packages = x.grep(/^Package: .+$/)
  end
  packages.map {|l| l.split(':').last.strip }
end

def installable_files(installfiles)
  foundfiles = []
  installfiles.each {|file|
    next unless Kernel.test('f',file)
    File.open(file) do |io|
     foundfiles << io.readlines().map {|line| line.strip }#split('/').last }
    end
  }
  foundfiles.flatten
end

class Set 
def fancy_print(header)
  if self.length > 0 then
    %Q(#{header}\n\t#{self.to_a.join("\n\t")})
  else
    nil
  end
end
end

def array_has_duplicates?(array)
  n = array.length - array.uniq.length 
  return n 
end
def aaaa(array)
  if array.length == array.uniq.length then
    0 
  else
    true
  end
end
def check_for_duplicates(txt, array)
  n = array_has_duplicates?(array) 
  if n > 0 then
    puts "#{txt} has duplicates. #{n} duplicate#{n==1? '': 's'}"
  end
end

def main()

  installfiles = ls_packages().map {|p|  sprintf TEMPLATE, p }
  installed_files = installable_files(installfiles).map{|x| x.split(INSTALL_PREFIX).last } 
  src_files = find_files(DIRS)
  check_for_duplicates('never should see this', src_files)
  check_for_duplicates('*.install file', installed_files)

  exists    = Set.new(src_files)
  installed = Set.new(installed_files)
  missing = exists ^ installed
  missing_vc = installed - exists
  missing_install = exists - installed

  n = missing.length
  if n > 0 then
    puts %Q(#{n} Missing file#{n == 1 ? '' : 's'})
    a = missing_vc.fancy_print("Missing file in src directory but present in .install files")
    puts a unless a.nil?
    a = missing_install.fancy_print("Missing from .install files but present in src directory") 
    puts a unless a.nil?
  else
    puts %Q(All files in #{DIRS.inspect} set to be installed in debian/*.install files)
  end
end
main()

__END__
Source: enki-scripts
Section: admin
Priority: extra
Maintainer: cfgdb <itcfg@example.com>
Build-Depends: cdbs, debhelper (>= 5), sed, make, dpkg-dev, fakeroot, findutils, awk
Standards-Version: 3.7.2

Package: enki-scripts
Section: admin
Architecture: all
Depends: dpkg, dsh, sudo, procps, ipcalc, bc, coreutils, iproute, ethtool, iptables, grep, bash (>= 3.2 )
Description: scripts for managing the ENKI platform

Package: enki-scripts-loadbalancers
Section: admin
Architecture: all
Depends: enki-scripts 
Description: ENKI Load balancers 

Package: enki-xmppsend
Section: admin
Architecture: all
Depends: enki-scripts, python, python-xmpp (>= 0.4.1)
Description: xmpp-send script to send message to jabber
