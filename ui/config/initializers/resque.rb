rails_root = ENV['RAILS_ROOT'] || File.dirname(__FILE__) + '/../..'
rails_env = ENV['RAILS_ENV'] || 'development'

resque_config = YAML.load_file(rails_root + '/config/resque.yml')
Resque.redis = resque_config[rails_env]

#require "resque/failure/multiple"
require 'resque-email-notifier'

Resque::Failure::Multiple.configure do |multi|
  # Always stores failure in Redis and writes to log
  multi.classes = Resque::Failure::Redis, Resque::Failure::Logger
  # Production/staging only: also email us a notification
  multi.classes << Resque::Failure::Notifier # if Rails.env.production? || Rails.env.staging?
end
