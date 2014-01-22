require 'active_support'
require 'net/http'
require 'uri'
require 'cgi'

class MyCacheStore < ActiveSupport::Cache::FileStore
  def key_file_path(key)
    uri = URI(key)
    path = uri.path
    path = '/' if !path or path == ''
    path = File.join(path, 'index.html') if path[-1] == '/'
    path << uri.query if uri.query
    path = CGI::unescape(path).gsub(/[<>:"|?*]/, '_')
    fragments = [@cache_path, uri.host, path].compact
    File.join(*fragments)
  end
end
if $0 == __FILE__
  Cache = ActiveSupport::Cache::FileStore.new '/tmp/cache'
end