#!/usr/bin/env ruby

require 'nokogiri'
# require 'open-uri'
require 'typhoeus'
require 'set'

STARTING_URL = 'http://www.quotationspage.com/quotes/Mark_Twain/'

CSS =<<EO_STYLE
  <style type="text/css">
      li {list-style-type: none; border-color: #b3b3b3; background-color: #e6e6e6; padding: 5px; border-width: 1px; border-style: ridge; margin-bottom: 5px; margin-top: 5px;}
      li:after { content: '"'; }
      li:before { content: '"'; }
      body { font-family: fantasy; }
  </style>
EO_STYLE

quotes = Set.new
requests = []

hydra = Typhoeus::Hydra.new(:max_concurrency => 5)

# 112 quotes spread over n pages with 30 quotes/page, starting with quote #1.
1.step(112, 30) do |_i|
  url = STARTING_URL
  url += _i.to_s if (_i > 1)

  request = Typhoeus::Request.new(url)
  request.on_complete do |response|
    print '.'
    doc = Nokogiri::HTML(response.body)
    
    # quotes are stored in <dt><a> elements.
    doc.css('dt a').map do |_n| 
      _n.inner_text.gsub(/[\r\n]+/, ' ').squeeze(' ').strip
    end
  end
  requests << request
  hydra.queue(request)
  
end
hydra.run
puts 
puts "Finished scanning #{ STARTING_URL }"

# these responses are returned as an array so add them to the previous ones.
requests.each { |r| quotes += r.handled_response }

requests = []
uri = URI.parse('http://www.brainyquote.com/quotes/quotes/m/marktwain100239.html')
doc = Nokogiri::HTML(Typhoeus::Request.get(uri.to_s).body)
doc.css('td span.body a').each do |_a|
  
  if (_a['href'][/marktwain\d+\.html$/])
    page_uri = uri.merge(_a['href'])
    
    request = Typhoeus::Request.new(page_uri.to_s)
    request.on_complete do |response|
      print '.'
      quote_doc = Nokogiri::HTML(response.body)
      quote_doc.at_css('span.huge').inner_text.gsub(/[\r\n]+/, ' ').squeeze(' ').strip
    end
    requests << request
    hydra.queue(request)
    
  end
end
hydra.run
puts
puts "Finished scanning #{ uri }"

# these responses are returned as individual statements so append them to the array.
requests.each { |r| quotes << r.handled_response }

puts
puts "#{quotes.size} quotes"

File.open('mark_twain_quotes.html', 'w') do |_fo|
  _fo.puts '<html><head><title>Mark Twain Quotes</title>'
  _fo.print CSS
  _fo.puts '</head><body><ul>'
  
  quotes.sort_by{ |a| a.downcase }.each { |q| _fo.puts "<li>#{ q }</li>" }
  
  _fo.puts "</ul></body></html>"
end

