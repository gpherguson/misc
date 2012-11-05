#!/usr/bin/env ruby

if (RUBY_VERSION < '1.8.7')
  puts "Needs Ruby v.1.8.7+"
  puts "This is #{ RUBY_VERSION }"
  exit
end

# Given a string of characters this code will search the dictionary and return
# all words found that can be made using subsets of those characters.

require 'rubygems'
require 'set'

DICTIONARY = '/usr/share/dict/web2'

if (ARGV.any?)
  letters = ARGV[0] 
else
  puts "#{$0} words to find"
  exit
end

# Open the dictionary and read it in, sorting the letters in the word into
# alphabetical order, folded to lower-case.
words = {}
IO.foreach(DICTIONARY) do |_word|
  _value = _word.chomp.strip.downcase

  next if ( 3 > _value.length || _value.length > letters.size )

  _key = _value.split('').sort.join

  # Add the resulting string to the hash of words as an array entry. If there
  # is a collision with an existing string, then append that to the value.
  if ( words.key?(_key) )
    words[ _key ] << _value
  else
    words[ _key ] = [ _value ]
  end
end

# loop over the combinations...
unique_words = Set.new
3.upto( letters.size ) do |c|

  letters.split('').permutation(c) do |s|

    s_index = s.sort.join

    next if unique_words.member?(s_index)

    unique_words << s_index

    s_word = s.join

    if ( words[ s_index ] && words[ s_index ].length > 0 )
      puts words[ s_index ].sort.uniq.join(', ')
    end
  end
end

