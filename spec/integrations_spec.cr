require "./spec_helper"
require "socket"

describe Freeswitch::ESL do
  describe Freeswitch::ESL::Outbound do
    it "handshake with channel data" do
      receive_events = Channel(Freeswitch::ESL::Event).new
      conn = Freeswitch::ESL::Outbound.listen("localhost", 0) do |_conn, events|
        # first event it's channel data
        channel_data = events.receive
        receive_events.send channel_data
      end

      client = TCPSocket.new(conn.address, conn.port)
      response = client.gets
      # when Freeswitch connects expect the word connect from the server
      response.should eq("connect"), "client must send connect"
      client.gets
      channel_data = %Q(Channel-Username: 1001
Channel-Dialplan: XML
Channel-Caller-ID-Name: 1001
Channel-Caller-ID-Number: 1001
Channel-Network-Addr: 10.0.1.241
Channel-Destination-Number: 886
Channel-Unique-ID: 40117b0a-186e-11dd-bbcd-7b74b6b4d31e
Channel-Source: mod_sofia
Channel-Context: default
Channel-Channel-Name: sofia/default/1001%4010.0.1.100
Channel-Profile-Index: 1
Channel-Channel-Created-Time: 1209749769132614
Channel-Channel-Answered-Time: 0
Channel-Channel-Hangup-Time: 0
Channel-Channel-Transfer-Time: 0
Channel-Screen-Bit: yes
Channel-Privacy-Hide-Name: no
Channel-Privacy-Hide-Number: no
Channel-State: CS_EXECUTE
Channel-State-Number: 4
Channel-Name: sofia/default/1001%4010.0.1.100
Unique-ID: 40117b0a-186e-11dd-bbcd-7b74b6b4d31e
Call-Direction: inbound
Answer-State: early
Channel-Read-Codec-Name: G722
Channel-Read-Codec-Rate: 16000
Channel-Write-Codec-Name: G722
Channel-Write-Codec-Rate: 16000
Caller-Username: 1001
Caller-Dialplan: XML
Caller-Caller-ID-Name: 1001
Caller-Caller-ID-Number: 1001
Caller-Network-Addr: 10.0.1.241
Caller-Destination-Number: 886
Caller-Unique-ID: 40117b0a-186e-11dd-bbcd-7b74b6b4d31e
Caller-Source: mod_sofia
Caller-Context: default
Caller-Channel-Name: sofia/default/1001%4010.0.1.100
Caller-Profile-Index: 1
Caller-Channel-Created-Time: 1209749769132614
Caller-Channel-Answered-Time: 0
Caller-Channel-Hangup-Time: 0
Caller-Channel-Transfer-Time: 0
Caller-Screen-Bit: yes
Caller-Privacy-Hide-Name: no
Caller-Privacy-Hide-Number: no
variable_sip_authorized: true
variable_sip_mailbox: 1001
variable_sip_auth_username: 1001
variable_sip_auth_realm: 10.0.1.100
variable_mailbox: 1001
variable_user_name: 1001
variable_domain_name: 10.0.1.100
variable_accountcode: 1001
variable_user_context: default
variable_effective_caller_id_name: Extension%201001
variable_effective_caller_id_number: 1001
variable_sip_from_user: 1001
variable_sip_from_uri: 1001%4010.0.1.100
variable_sip_from_host: 10.0.1.100
variable_sip_from_user_stripped: 1001
variable_sip_from_tag: wrgb4s5idf
variable_sofia_profile_name: default
variable_sofia_profile_domain_name: 10.0.1.100
variable_sofia_profile_domain_name: 10.0.1.100
variable_sip_req_params: user%3Dphone
variable_sip_req_user: 886
variable_sip_req_uri: 886%4010.0.1.100
variable_sip_req_host: 10.0.1.100
variable_sip_to_params: user%3Dphone
variable_sip_to_user: 886
variable_sip_to_uri: 886%4010.0.1.100
variable_sip_to_host: 10.0.1.100
variable_sip_contact_params: line%3Dnc7obl5w
variable_sip_contact_user: 1001
variable_sip_contact_port: 2048
variable_sip_contact_uri: 1001%4010.0.1.241%3A2048
variable_sip_contact_host: 10.0.1.241
variable_channel_name: sofia/default/1001%4010.0.1.100
variable_sip_call_id: 3c2bb21af10b-ogphkonpwqet
variable_sip_user_agent: snom300/7.1.30
variable_sip_via_host: 10.0.1.241
variable_sip_via_port: 2048
variable_sip_via_rport: 2048
variable_max_forwards: 70
variable_presence_id: 1001%4010.0.1.100
variable_sip_h_P-Key-Flags: keys%3D%223%22
variable_switch_r_sdp: v%3D0%0D%0Ao%3Droot%201915884124%201915884124%20IN%20IP4%2010.0.1.241%0D%0As%3Dcall%0D%0Ac%3DIN%20IP4%2010.0.1.241%0D%0At%3D0%200%0D%0Am%3Daudio%2062258%20RTP/AVP%209%202%203%2018%204%20101%0D%0Aa%3Drtpmap%3A9%20g722/8000%0D%0Aa%3Drtpmap%3A2%20g726-32/8000%0D%0Aa%3Drtpmap%3A3%20gsm/8000%0D%0Aa%3Drtpmap%3A18%20g729/8000%0D%0Aa%3Drtpmap%3A4%20g723/8000%0D%0Aa%3Drtpmap%3A101%20telephone-event/8000%0D%0Aa%3Dfmtp%3A101%200-16%0D%0Aa%3Dptime%3A20%0D%0A
variable_remote_media_ip: 10.0.1.241
variable_remote_media_port: 62258
variable_read_codec: G722
variable_read_rate: 16000
variable_write_codec: G722
variable_write_rate: 16000
variable_open: true
variable_socket_host: 127.0.0.1
variable_local_media_ip: 10.0.1.100
variable_local_media_port: 62258
variable_endpoint_disposition: EARLY%20MEDIA
Content-Type: command/reply
Socket-Mode: async
Control: full

)
      # after 'connect' freeswitch send channel data
      client.write(channel_data.encode("utf-8"))

      event = wait_for(receive_events)
      event.headers["variable_socket_host"].should eq "127.0.0.1"
      client.close
    end
  end
end
