APP_ROOT  = 'export/web/cnu_it'
APP_FAKEROOT =  "$(FAKEROOT)/#{APP_ROOT}"

require  'etc'

class Txtfile 
  attr_accessor :path
  def initialize(p)
    self.path = Pathname.new(p)
  end
  def to_s
    "#{self.class}: #{path.to_s}"
  end
  def q(s)
     '"' + s + '"'
  end
  def install_cmd
      "install -D -m 644" 
  end
  def install_src
    "$(SRC)/#{path.to_s}"
  end 
  def install_dest
      "#{APP_FAKEROOT}/#{path.to_s}"
  end
  def debian_install_cmd
    [install_cmd, q(install_src), q(install_dest)].join(' ') 
  end
end
class Configfile < Txtfile
  def install_cmd
      "install -D -m 640 " 
  end
end
class Linkfile < Txtfile
  attr_accessor :link_dest
  def initialize(p)
    super(p)
    self.link_dest = File.readlink(p)
  end
  def to_s
    "#{self.class}: +l #{path.to_s}"
  end
  def install_cmd
    "@ln -s "
  end
  def install_src
      link_dest 
  end
end

class Exefile < Txtfile
  def install_cmd
    "install -m 755 "
  end
  def to_s
    "#{self.class}: +x #{path.to_s}"
  end
end

DIRS = %w( . )

def directories()
  DIRS
end

FILES=["debian/package.dirs", 'rules1.mk'] 
OTHER_FILES = ['build-stamp','install-stamp']


def is_non_production_yaml?(path)
  return false unless path =~ /\/config\/\w+\.yml$/ 
  if path =~ /\/config\/\w+_production\.yml$/ then
    false
  else
    
    true
  end
end

def filetype(path)
    # stat = File::Stat.new(path)
    return nil if Kernel.test('d', path) and not Kernel.test('l', path) 
    return nil if OTHER_FILES.member? path 
    return nil if FILES.member? path 
    if is_non_production_yaml?(path) then
        STDERR.puts "skipping file: #{path}"
        return nil
    end 
    return nil if path =~ /config.database.yml$/
    return nil if path =~ /config.ldap.yml$/
#    return nil if path =~ Pathname.new(path).dirname =~ /^debian$/
    if Kernel.test('l', path) then 
      Linkfile.new(path)
    elsif Kernel.test('x',path) then
      Exefile.new(path)
    elsif path =~ %r|^[\.\/]+config/| then
      Configfile.new(path)
    else
      Txtfile.new(path)
    end
end
require 'find'


def dpkg_find( &block)
  prune_dirs = ['debian','.git','test', 'faker' , 'machinist' , 'capybara-0.3.9',
  'childprocess-0.0.7', 'culerity-0.2.12', 'mime-types-1.16',
  'rack-test-0.5.6', 'rubyzip-0.9.4', 'selenium-webdriver-0.0.29']

  directories.map { |dir|
    f = []
    Find.find(dir) do |path|
      if prune_dirs.member? File.basename(path) then
        Find.prune
      elsif FILES.member? File.basename(path) then
        next
      elsif OTHER_FILES.member? File.basename(path) then
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

def files()
  dpkg_find do |path|
    if path =~ /\.log$/ then
      nil  
    else
      filetype(path)
    end
  end
end
def parsechangelog
  changelog = %x{dpkg-parsechangelog}
  package, version = changelog.split("\n")[0,2].map{|x| x.split.last }
  arch = %x{dpkg-architecture -qDEB_HOST_ARCH}.chomp
  [ package, version, arch ] 
end
def debian_package(clog) 
  "#{clog.join('_')}.deb"
end
def package_version
  clog = parsechangelog
  clog[1]
end
namespace :debian do

task :build => 'build:debian' do |t|
end
task :clean => 'build:clean' do |t|
end

end

namespace :build do

file 'rules1.mk' => ['lib/tasks/build.rake','Rakefile','.'] do |t|
  puts 'building rules1.mk'
  s = files().map{|f| "\t@" + f.debian_install_cmd }
  open(t.name,'w') do |io|
    io.puts "#
# auto generated 
#
ifndef SRC
SRC=.
endif
install-files::"
    io.puts s
  end
end

file "debian/package.dirs" => ['lib/tasks/build.rake','Rakefile','.'] do |t|
  puts 'building debian/package.dirs file listing'
  dirs = dpkg_find do |path|
          if Kernel.test('d', path) and not Kernel.test('l',path) then
            path 
          end
  end
  open(t.name, 'w') do |io|
      dirs.each { |d1| io.puts "#{APP_ROOT}/#{d1}" }
  end 
end


task :files => FILES  do |t|
    puts 'built files'
end

def no_key
  false
end

desc 'build debian package'
task :debian  => [:user, :plugins, FILES].flatten do |t|
	puts "building ..."
  sh 'dpkg-buildpackage -rfakeroot -uc -us '
end

desc 'submit last package to somewhere.'
task :publish   do |t|
  changelog = parsechangelog
  fn = "../#{debian_package(changelog)}"
  if Kernel.test('rf', fn) then 
    host = 'somewhere.obr'
    sh "scp '#{fn}' '#{host}:' "
    sh "git commit -s -m'#{package_version} build changelog' debian/changelog" 
    pending_commits = %x[git log --pretty=oneline origin..master | wc -l].chomp.to_i
    if pending_commits == 1
      sh "git push"
      puts "\ndebian/changelog commited and pushed."
    else
      puts "\nYou have other pending commits. Please push the debian/changelog commit manually."
    end
  else
    raise "Error, can't find or read file #{fn}"
  end
end

task :user do |t|
  Etc.getgrnam('cnuit')
  Etc.getpwnam('cnuit')
end

desc 'checkout plugins'
task :plugins => [] do |t|
  sh 'vendor/plugins/get-versions.rb'
end 

desc 'clean up'
task :clean => [] do 
  sh 'dh_clean'
  [FILES, OTHER_FILES].flatten.each {|f| rm_f f }
  rm_f `ls debian/*.dirs`.strip
#  rm_f 'build-stamp'
#  rm_f 'install-stamp'
end

def find_ver(h) 
  h.keys.select {|k| k =~ /^version$/i }.map { |v| h[v] }.sort.first 
end

desc 'add a changelog entry - use version=0.0.0 to set version'
task :changelog => [] do
  v = find_ver(ENV)
  opt = "-i"
  opt = "-v #{v}" unless v.nil?
  distro = `lsb_release -i`
  if distro =~ /Ubuntu/ then
     distributor = "--distributor Debian"
  else
     distributor = ""
  end
  sh "dch --no-auto-nmu #{distributor} --distribution stable #{opt}"
end
desc 'list the version of the package from changelog'
task :version => [] do
  puts package_version
end

end #end of namespace
