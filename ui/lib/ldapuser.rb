#!/usr/bin/ruby
require 'rubygems'
require 'ldap'
require 'timeout'
require 'digest'
require 'base64'

class LdapUser
	attr_accessor :username, :firstName, :lastName, :emailAddress

	def initialize(username)
	    @ldap_config = YAML::load(File.open("#{RAILS_ROOT}/config/ldap.yml"))[RAILS_ENV]
		status = Timeout::timeout(3) {
		@conn = LDAP::Conn.new(@ldap_config[:name], @ldap_config[:port])
		@conn.set_option(LDAP::LDAP_OPT_PROTOCOL_VERSION, 3)
		begin
			@conn.search(@ldap_config[:base_dn], LDAP::LDAP_SCOPE_SUBTREE, "(uid:dn:=#{username})") { |user|
				@username = user["uid"]
				@firstName = user["givenName"]
				@lastName = user["sn"]
				@emailAddress = user["mail"]
				@dn = user.dn
			}
		rescue LDAP::ResultError
			return nil
		
		rescue Exception
			return nil
		end
		}
	end

	def authenticate(password)
		begin
			@conn.bind(@dn, password)
			@conn.unbind
			true	
		rescue LDAP::ResultError => err
			if err.message == "Invalid credentials" then
				return nil
			end
		end
	end
	
end
