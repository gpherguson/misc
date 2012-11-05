TEXT = 'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor magna'
TARGETS = [ /(am?et)/, /(ips.m)/, /(elit)/, /(magna)/, /([Ll]or[eu]m)/ ]
TARGET_REGEX_UNION = Regexp.union(TARGETS)

hits = []
TEXT.scan(TARGET_REGEX_UNION) { |a| hits += a.each_with_index.to_a }
hits.select{ |w,i| w }.map{ |w,i| TARGETS[i] } # => [/([Ll]or[eu]m)/, /(ips.m)/, /(am?et)/, /(elit)/, /(magna)/]
hits.select{ |str,i| str }                     # => [["Lorem", 4], ["ipsum", 1], ["amet", 0], ["elit", 2], ["magna", 3]]
