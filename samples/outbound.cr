require "../src/freeswitch-esl.cr"
require "log"

USAGE = "usage: outbound <host> <port>"
raise USAGE if ARGV.size < 2


host = ARGV[0]
port = ARGV[1].to_i

Log.setup(:debug)

Freeswitch::ESL::Outbound.listen(host, port) do |conn, events|
  channel_data = events.receive
  puts channel_data.headers

  resp = conn.execute "answer"
  puts resp
  conn.execute "hangup"
end

sleep
