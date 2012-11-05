#!/usr/bin/env ruby

# Some code to get the IP address of the host node, because sometimes that is
# useful to know.

require 'socket'

def local_ip
  orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true  # turn off reverse DNS resolution temporarily

  UDPSocket.open do |s|
    s.connect '192.168.0.1', 1
    s.addr.last
  end
ensure
  Socket.do_not_reverse_lookup = orig
end         

p local_ip  
