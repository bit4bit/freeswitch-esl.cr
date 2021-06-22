require "./spec_helper"

describe Freeswitch::ESL do
  describe Freeswitch::ESL::Connection do
    it "read partial" do
      reader, writer = IO.pipe

      partial1 = %Q(
Content-Length: 509
Content-Type: text/event-json

{"Event-Name":"API","Core-UUID")

      writer.write partial1.encode("utf-8")

      conn = Freeswitch::ESL::Connection.new(reader)
      spawn do
        partial2 = %Q(:"e9c1f424-6460-4f37-8f40-64479a1a35f9","FreeSWITCH-Hostname":"fef3c021a821","FreeSWITCH-Switchname":"fef3c021a821","FreeSWITCH-IPv4":"172.29.0.9","FreeSWITCH-IPv6":"::1","Event-Date-Local":"2021-06-22 22:22:48","Event-Date-GMT":"Tue, 22 Jun 2021 22:22:48 GMT","Event-Date-Timestamp":"1624400568854903","Event-Calling-File":"switch_loadable_module.c","Event-Calling-Function":"switch_api_execute","Event-Calling-Line-Number":"2996","Event-Sequence":"675","API-Command":"uptime"})
        writer.write partial2.encode("utf-8")
      end

      events = conn.channel_events

      select
      when event = events.receive
        event.message.fetch("FreeSWITCH-Switchname", nil).should eq "fef3c021a821"
      when timeout 1.second
        raise "timeout"
      end
    end

    it "read event json" do
      data = %Q(Content-Length: 540
Content-Type: text/event-json

{"Event-Name":"API","Core-UUID":"e9c1f424-6460-4f37-8f40-64479a1a35f9","FreeSWITCH-Hostname":"fef3c021a821","FreeSWITCH-Switchname":"fef3c021a821","FreeSWITCH-IPv4":"172.29.0.9","FreeSWITCH-IPv6":"::1","Event-Date-Local":"2021-06-22 22:47:41","Event-Date-GMT":"Tue, 22 Jun 2021 22:47:41 GMT","Event-Date-Timestamp":"1624402061434932","Event-Calling-File":"switch_loadable_module.c","Event-Calling-Function":"switch_api_execute","Event-Calling-Line-Number":"2996","Event-Sequence":"875","API-Command":"sofia","API-Command-Argument":"status"})
      reader, writer = IO.pipe

      conn = Freeswitch::ESL::Connection.new(reader)
      writer.write data.encode("utf-8")

      events = conn.channel_events

      select
      when event = events.receive
        event.message.fetch("FreeSWITCH-Switchname", nil).should eq "fef3c021a821"
      when timeout 1.second
        raise "timeout"
      end
    end
  end
end
