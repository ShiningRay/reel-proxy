require 'celluloid'
require 'net/http'
require 'connection_pool'
require 'active_support/core_ext/class/attribute'

require_relative './cache'


class Prefetcher
  include Celluloid
  include Celluloid::Logger
  include Celluloid::Notifications
  # class_attribute :connection_pool
  # self.connection_pool = ConnectionPool.new(size: 5, timeout: 30) { Net::HTTP.new('nodejs.org', 80).start }
  attr_reader :server

  def initialize(server)
    @server = server
    @target = server.target
  end

  def fetch url
    if url.is_a?(URI)
      uri = url
      url = uri.to_s
    else
      uri = URI(url)
    end
    debug "prefetching #{uri}"
    if uri.host == @target.host and !Cache.exist?(url)
      server.store url, Net::HTTP.get_response(uri)
    end

  rescue => e
    puts e.backtrace
  end
end


if $0 == __FILE__
  require 'pp'
  k ='http://nodejs.org'
  prefetcher = Prefetcher.pool
  prefetcher.fetch k
  c = Cache.read(k)
  puts c.body
  Cache.delete k
end
