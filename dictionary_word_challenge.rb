#!/usr/bin/env ruby

require 'set'

# Given a dictionary, output all word pairs where both words share all their
# letters except the last two, which are distinct and reversed.
# 
# Notes:
# - use a reasonable dictionary of your choice
# - potential word pairs are: "ear, era" ; "revies, revise" ; "burglaries, burglarise"
# - "shear, era" is not a valid pair because "she" != "e"
# - "bell, bell" is not a valid pair because the last two letters are not distinct
#
# additional word pairs for testing are: "crate, caret, carte"

DICTIONARY = ARGV.first || '/usr/share/dict/words'

# build a hash of the words:
#
#   key (sorted characters in word)
#   values [word1, word2]

word_hash = {}
# %w( crate caret carte ).each do |_word|
# %w( burglaries burglarise ear era revies revise shear era bell bell crate caret carte ).each do |_word|
IO.foreach(DICTIONARY) do |_word|
  word_value = _word.chomp.downcase

  # reject any words that have the same last two characters...
  next if ( (word_value.length < 3) || (word_value[-1] == word_value[-2]) )
  
  word_key = word_value[0 .. -3].split('').sort.join + word_value[-2 .. -1].split('').sort.join
  if (word_hash[word_key])
    word_hash[ word_key ] << word_value 
  else 
    word_hash[ word_key ] = Set.new(word_value)
  end
end

# find all the keys that have multiple values...
word_hash.each do |_key, _words|

  next if (_words.size == 1)
  word_array = _words.to_a

  word1      = word_array.shift
  last_two   = word1[-2..-1]
  word_array = word_array.select{ |_w| _w[-2..-1] == last_two.reverse }

  if (word_array.any?)
    print word1, ' --> ', word_array.join(', '), "\n"
  end
end

