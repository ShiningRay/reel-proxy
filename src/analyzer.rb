require 'celluloid'
require 'nokogiri'

require_relative './prefetcher'

class Analyzer
  include Celluloid
  include Celluloid::Logger
  include Celluloid::Notifications

  attr_reader :prefetcher
  def initialize(prefetcher)
    @prefetcher = prefetcher
    subscribe('stored', :analyze)
  end

  def analyze(topic, key)
    debug "analyzing #{key}"
    attr_extractor = proc{|attr| proc{|node| node[attr]}}
    href_extractor = attr_extractor['href']
    src_extractor = attr_extractor['src']

    if content = Cache.read(key)
      unless content['content-type'] =~ /html/i
        return debug("#{key}'not html skip'")
      end
      doc = Nokogiri::HTML(content.body)
      links = doc.css('a,link').map(&href_extractor) + \
              doc.css('script,img,frame,iframe').map(&src_extractor)
      links.each do |l|
        unless l =~ /\A(#|javascript:)/
          begin
            prefetcher.async.fetch(URI.join(key, (l || '').strip))
          rescue URI::InvalidURIError
            info "Bad URI #{key} #{l}"
          end
        end
      end  # reject all the anchors
    end
  end
end

if $0 == __FILE__
  require 'pp'
  Analyzer.supervise_as :analyzer
  prefetcher = Celluloid::Actor[:prefetcher] = Prefetcher.pool
  k = 'http://nodejs.org'
  prefetcher.fetch k
  pp Celluloid::Actor[:analyzer].analyze k

end

