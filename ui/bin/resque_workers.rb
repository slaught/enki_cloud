#!/usr/bin/ruby

require 'pathname'

# when in a bin or script dir
$:.unshift(Pathname.new($0).realpath.dirname.join('../lib').realpath)
#$:.unshift(Pathname.new($0).realpath.dirname.join('../app/models').realpath)
$:.unshift(Pathname.new($0).realpath.dirname.join('..').realpath)
$:.unshift(Pathname.new($0).realpath.dirname.realpath)

puts "STARTING"

ENV['RAILS_ENV'] = 'production' if ENV['RAILS_ENV'].nil?

require 'config/environment'
require 'resque'

worker = nil
queues = (ENV['QUEUES'] || ENV['QUEUE'] || "*").to_s.split(',')

puts "BEGIN"
begin
  worker = Resque::Worker.new(*queues)
  worker.verbose = ENV['LOGGING'] || ENV['VERBOSE']
  worker.very_verbose = ENV['VVERBOSE']
rescue Resque::NoQueueError
  abort "set QUEUE env var, e.g. $ QUEUE=critical,high rake resque:work"
end
worker.log "Starting worker #{worker}"
worker.work(ENV['INTERVAL'] || 5) # interval, will block

puts "ENDING"
