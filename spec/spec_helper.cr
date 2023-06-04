require "spec"
require "../src/freeswitch-esl"

def wait_for(receive_events)
  select
  when event = receive_events.receive
    return event
  when timeout 1.second
    raise "timeout"
  end
end

def write_part(writer)
  data = yield
  writer.write data.encode("utf-8")
end
