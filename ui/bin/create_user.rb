#!/usr/bin/ruby

require 'pathname'

# when in a bin or script dir
$:.unshift(Pathname.new($0).realpath.dirname.join('../lib').realpath)
$:.unshift(Pathname.new($0).realpath.dirname.join('../app/models').realpath)
$:.unshift(Pathname.new($0).realpath.dirname.join('..').realpath)
$:.unshift(Pathname.new($0).realpath.dirname.realpath)

ENV['RAILS_ENV'] = 'production' if ENV['RAILS_ENV'].nil?

require 'config/environment'

DEFAULT_PASSWORD = 'password'

def maildomain
  domain = nil
  mailname_fn = '/etc/mailname'
  if File.exist?(mailname_fn) and File.readable?(mailname_fn)
    File.open('/etc/mailname') { |io|  
      domain = io.readline
    }
  else
    domain = `hostname -d`
  end 
  domain.chomp
end
def main()
  u = User.new
  print "What is user's full name?: "
  u.name = gets.strip

  login = (u.name.split[0][0].chr + u.name.split[-1]).downcase
  print "Is the user's login #{login}? [Y/n]: "
  result = gets.strip
  until ['Y', 'y', 'N', 'n', ''].include? result do
    print "Please answer 'y' or 'n': "
    result = gets.strip
  end
  if result == 'Y' or result == 'y' or result.blank?
    u.login = login
  else result == 'N' or 'n'
    print "What is user's login?: "
    u.login = gets.strip
  end

  u.email = "#{u.login}@#{maildomain}"
  u.password = DEFAULT_PASSWORD
  u.password_confirmation = DEFAULT_PASSWORD
  u.roles << Role.find_by_name('sysadmin')

  if u.save
    puts "Sysadmin user successfully created for #{u.login}:"
    puts u.reload.inspect
  else
    puts "Problem creating user: #{u.errors.full_messages}"
  end
end

main()
__END__

