require 'rubygems'
require 'bundler/setup'
require 'reel'
require 'celluloid/io'
require 'celluloid/autostart'
require 'net/http'
require 'time'
require 'active_support/core_ext/time'
require 'active_support/core_ext/hash/indifferent_access'
require 'pp'
require 'yaml'

require_relative './cache'
require_relative './prefetcher'
require_relative './analyzer'
require_relative './connection'

class ProxyServer < Reel::Server::HTTP
  include Celluloid
  include Celluloid::Notifications
  include Celluloid::Logger
  attr_reader :configuration, :target, :upstream
  def initialize(host="0.0.0.0", port=8001)
    info "Time server example starting on #{host}:#{port}"
    @configuration = YAML.load_file('config.yml').with_indifferent_access
    debug @configuration.inspect
    configuration[:listen][:address] ||= host
    configuration[:listen][:port] ||= port
    @target = URI(@configuration[:target])
    super(configuration[:listen][:address], configuration[:listen][:port], &method(:on_connection))
  end

  def on_connection(connection)
    connection.detach
    ProxyConnectionHandler.new(connection, Actor.current)
  end

  def store url, res
    if res.code == "200" and res['cache-control'].to_s !~ /no-cache/
      debug "storing #{url}"
      res['Expires'] ||= (Time.now + 1800).httpdate
      publish('stored', url) if Cache.write url, res
    else
      debug "not 200 ok #{res.code}"
      debug "#{res.inspect}"
    end
    res
  end
end

ProxyServer.supervise_as :proxy_server
# Celluloid::Actor[:prefetcher] = Prefetcher.pool
Prefetcher.supervise_as(:prefetcher, Celluloid::Actor[:proxy_server])
Analyzer.supervise_as :analyzer, Celluloid::Actor[:prefetcher]
Cache = MyCacheStore.new Celluloid::Actor[:proxy_server].configuration[:cache]
if __FILE__ == $0
  sleep
end
