#!/usr/bin/ruby

def choose_weighted(weighted)
  sum = weighted.inject(0) do |sum, item_and_weight|
    sum += item_and_weight[1]
  end

  target = rand(sum)

  weighted.each do |item, weight|
    return item if target <= weight
    target -= weight
  end
end

lottery_probabilities = {
  '-1'   => 1000,
  '0'    => 50,
  '+2'   => 20,
  '+5'   => 10,
  '+10'  => 5,
  '+100' => 1
}

probability = {
  '-1'   => 0,
  '0'    => 0,
  '+2'   => 0,
  '+5'   => 0,
  '+10'  => 0,
  '+100' => 0
}

winnings = 0

100.times { 
  p = choose_weighted(lottery_probabilities) 
  probability[p] += 1

  # puts p
  winnings += p.to_i
}

probability.keys
  .sort { |a,b| a.to_i <=> b.to_i }
  .each { |k| print "%5s | %-3d %s\n" % [ k, k.to_i * probability[k], '*' * probability[k] ] }

# probability.keys.each {|k| winnings += k.to_i * probability[k] if (probability[k] > 0)}
puts (winnings >= 0) ? "Won #{winnings}" : "Lost #{winnings}"
