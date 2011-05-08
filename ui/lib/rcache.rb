require 'redis/namespace'

begin
  require 'yajl'
rescue LoadError
  require 'json'
end

module Rcache
  extend self
  # Accepts:
  #   1. A 'hostname:port' string
  #   2. A 'hostname:port:db' string (to select the Redis db)
  #   3. A 'hostname:port/namespace' string (to set the Redis namespace)
  #   4. A redis URL string 'redis://host:port'
  #   5. An instance of `Redis`, `Redis::Client`, `Redis::DistRedis`,
  #      or `Redis::Namespace`.
  def redis=(server)
    if server.respond_to? :split
      if server =~ /redis\:\/\//
        redis = Redis.connect(:url => server)
      else
        server, namespace = server.split('/', 2)
        host, port, db = server.split(':')
        redis = Redis.new(:host => host, :port => port,
          :thread_safe => true, :db => db)
      end
      namespace ||= :rcache

      @redis = Redis::Namespace.new(namespace, :redis => redis)
    elsif server.respond_to? :namespace=
        @redis = server
    else
      @redis = Redis::Namespace.new(:rcache, :redis => server)
    end
  end

  # Returns the current Redis connection. If none has been created, will
  # create a new one.
  def redis
    return @redis if @redis
    self.redis = 'localhost:6379'
    self.redis
  end

  def lookup(key)
    val = redis.get(key)
    ret = nil
    unless val.nil?
      begin
        ret = JSON.parse(val)[0]
      rescue JSON::ParserError
        ret = val
      end
    end
    ret
  end

  def lookup_or(key, &block)
    begin
      res = lookup(key)
      if res.nil?
        res = yield
        store(key, res)
      end
    rescue Errno::ECONNREFUSED
      res = yield
    end

    res
  end

  def store(key, value)
    redis.set(key, [value, key].to_json)
  end

  def clear(key)
    redis.del(key)
  end 

  def clear_all(key_pattern)
    keys = redis.keys(key_pattern)
    redis.del(*keys)
  end

end
