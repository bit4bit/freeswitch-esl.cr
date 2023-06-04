require "./spec_helper"

describe Freeswitch::ESL do
  describe Freeswitch::ESL::Connection do
    it "read fragmented data" do
      reader, writer = IO.pipe
      # write part
      write_part(writer) do
%Q(
Content-Length: 509
Content-Type: text/event-json

{"Event-Name":"API","Core-UUID")
      end

      conn = Freeswitch::ESL::Connection.new(reader)
      spawn do
        # write part
        write_part(writer) do
        %Q(:"e9c1f424-6460-4f37-8f40-64479a1a35f9","FreeSWITCH-Hostname":"fef3c021a821","FreeSWITCH-Switchname":"fef3c021a821","FreeSWITCH-IPv4":"172.29.0.9","FreeSWITCH-IPv6":"::1","Event-Date-Local":"2021-06-22 22:22:48","Event-Date-GMT":"Tue, 22 Jun 2021 22:22:48 GMT","Event-Date-Timestamp":"1624400568854903","Event-Calling-File":"switch_loadable_module.c","Event-Calling-Function":"switch_api_execute","Event-Calling-Line-Number":"2996","Event-Sequence":"675","API-Command":"uptime"})
        end
      end

      events = conn.channel_events

      event = wait_for(events)
      event.message.fetch("FreeSWITCH-Switchname", nil).should eq "fef3c021a821"
    end

    it "read event json" do
      reader, writer = IO.pipe

      conn = Freeswitch::ESL::Connection.new(reader)
      write_part(writer) {
%Q(Content-Length: 540
Content-Type: text/event-json

{"Event-Name":"API","Core-UUID":"e9c1f424-6460-4f37-8f40-64479a1a35f9","FreeSWITCH-Hostname":"fef3c021a821","FreeSWITCH-Switchname":"fef3c021a821","FreeSWITCH-IPv4":"172.29.0.9","FreeSWITCH-IPv6":"::1","Event-Date-Local":"2021-06-22 22:47:41","Event-Date-GMT":"Tue, 22 Jun 2021 22:47:41 GMT","Event-Date-Timestamp":"1624402061434932","Event-Calling-File":"switch_loadable_module.c","Event-Calling-Function":"switch_api_execute","Event-Calling-Line-Number":"2996","Event-Sequence":"875","API-Command":"sofia","API-Command-Argument":"status"})
      }

      events = conn.channel_events

      event = wait_for(events)
      event.message.fetch("FreeSWITCH-Switchname", nil).should eq "fef3c021a821"
    end
  end
end

