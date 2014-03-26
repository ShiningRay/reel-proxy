require 'celluloid'
require 'http'
require 'uri'
require_relative './cache'

class ProxyConnectionHandler
  include Celluloid
  include Celluloid::Logger
  include Celluloid::Notifications
  finalizer :on_close
  attr_reader :connection, :server

  def initialize(connection, server)
    @timer = after(30){  terminate }
    @connection = connection
    @server = server
    @target = server.target
    async.run
  end

  def on_close
    @connection.close
  end

  def run
    @connection.each_request { |req| @timer.reset; handle_request(req) }
  end

  def expired?(res)
    res.headers['Expires'] && Time.parse(res.headers['Expires']).past?
  end

  def revalidate(uri, force=false)
    uri = URI(uri) if uri.is_a?(String)
    debug "revalidating #{uri}"
    cache = load_cache(uri.to_s)
    headers = {}
    if cache
      return if !force and expired?(cache)
      headers['If-None-Match'] = cache.headers['Etag']
      headers['If-Modified-Since'] = cache.headers['Last-Modified'] || cache.headers['Date']
    end
    headers.delete_if { |k, v| v.nil? }
    store(uri.to_s, convert_response(HTTP.with(headers).get(uri)))
  end

  def store url, res
    if res.status.to_i == 200 and res.headers['Cache-Control'].to_s !~ /no-cache/
      debug "storing #{url}"
      #binding.pry
      publish('stored', url) if save_cache url, res
    else
      debug "not 200 ok #{res.status.inspect}"
    end
    res
  end

  def pass(request, uri)
    request.headers['Host'] = "#{@target.host}:#{@target.port||80}"
    request.headers.delete 'Accept-Encoding'
    debug "passing #{@target} #{uri} #{request.method} #{request.url}"
    convert_response(HTTP.request(request.method, uri, headers: request.headers, body: request.body.to_s))
  end

  def handle_request(request)
    uri = request.uri.dup
    uri.scheme ||= @target.scheme
    uri.host ||= @target.host
    uri.port ||= @target.port || 80
    url = uri.to_s
    need_revalidate = false
    if request.method == 'GET'
      if upres = load_cache(url) #and upres.is_a?(HTTPResponse)
        debug 'hit'
        need_revalidate = true
      else
        debug 'miss'
        request.headers.delete 'If-Modified-Since'
        request.headers.delete 'If-None-Match'
        upres = pass(request, uri)
        store(url, upres)
      end
    else
      upres = pass(request, uri)
    end
    if upres.headers['Location']
      location = URI(upres.headers.delete('Location'))
      location.host = request.uri.host
      location.port = request.uri.port
      upres.headers['Location'] = location.to_s
    end
    request.respond upres
    async.revalidate(url) if need_revalidate
  end
  protected
  def convert_response upres
    return upres if upres.is_a?(Reel::Response)
    h = {}
    upres.headers.each do |key, val|
      h[key]=val
    end
    h.delete "Transfer-Encoding"
    res = Reel::Response.new(upres.code.to_i, h, upres.body.to_s)
  end
  def load_cache key
    if val = Cache.read(key)
      Reel::Response.new val[:status], val[:headers], val[:body]
    end
  end

  def save_cache key, val
    Cache.write key, {status: val.status, headers: val.headers.to_hash, body: val.body.to_s}
  end
end
