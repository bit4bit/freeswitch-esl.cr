# fs_cli example

require "../src/freeswitch-esl.cr"

USAGE = "usage: fs_cli <host> <port> <pass>"

raise USAGE if ARGV.size < 3

host = ARGV[0]
port = ARGV[1].to_i
pass = ARGV[2]

conn = Freeswitch::ESL::Inbound.new(host, port, pass)
conn.connect(1.second)
conn.set_events("ALL")

channel = conn.events

puts conn.api "uptime"

loop do
  event = channel.receive
  puts event.headers
  puts event.message
end
