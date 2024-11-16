require "socket"
require "json"

module Freeswitch::ESL
  # This class allows do administrative task on a FreeSWITCH
  class Inbound
    @conn : Connection? = nil

    def initialize(@host : String, @port : Int32, @pass : String, @user : String? = nil)
    end

    def initialize(@conn : Connection, @pass : String, @user : String? = nil)
      @host = ""
      @port = 0
    end

    # allows execution of https://developer.signalwire.com/freeswitch/FreeSWITCH-Explained/Modules/mod_commands_1966741
    def api(app, arg = nil)
      conn.api(app, arg)
    end

    # subcribe to events https://developer.signalwire.com/freeswitch/FreeSWITCH-Explained/Introduction/Event-System/Event-List_7143557/#nat
    def set_events(name : String)
      conn.set_events(name)
    end

    # Tells FreeSWITCH not to close the socket connection when a channel hangs up.
    # Instead, it keeps the socket connection open until the last event related to the channel has been received by the socket client.
    def linger
      conn.block_send("linger")
    end

    # Disable socket lingering. See linger above.
    def nolinger
      conn.block_send("nolinger")
    end

    def myevents(uuid : String)
      conn.block_send("myevents json #{uuid}")
    end

    # Specify event types to listen for
    def filter(key, value = "")
      conn.block_send("filter #{key} #{value}")
    end

    # Specify the events which you want to revoke the filter. 
    # filter delete can be used when some filters are applied wrongly or when there is no use of the filter.
    def filter_delete(key, value = "")
      conn.block_send("filter delete #{key} #{value}")
    end

    # change level log 0 - CONSOLE 1 - ALERT 2 - CRIT 3 - ERR 4 - WARNING 5 - NOTICE 6 - INFO 7 - DEBUG
    def log(level)
      conn.block_send("log #{level}")
    end

    # Disable log output previously enabled by the log command
    def nolog
      conn.block_send("nolog")
    end

    # Suppress the specified type of event. Useful when you want to allow 'event all' followed by 'nixevent <some_event>' to see all but 1 type of event.
    def nixevent(events : String)
      conn.block_send("nixevent #{events}")
    end

    # Disable all events that were previously enabled with event.
    def noevents
      conn.block_send("noevents")
    end

    # Close the socket connection.
    def exit
      conn.block_send("exit")
      conn.close
    end

    # Send an event into the event system.
    # see https://developer.signalwire.com/freeswitch/FreeSWITCH-Explained/Modules/mod_event_socket_1048924/#38-sendevent
    def sendevent(event, headers : Hash(String, String | Int64) = {} of String => String | Int64, body = "")
      # https://freeswitch.org/confluence/display/FREESWITCH/mod_event_socket#sendevent
      # more details
      msg = String.build do |str|
        content_length = body.size

        str << "sendevent #{event}\n"
        headers.each do |k, v|
          str << "#{k}: #{v}\n"
        end
        if content_length > 0
          str << "content-length: #{content_length}\n"
          str << "\n\n"
          str << body
        end
      end

      conn.block_send msg
    end

    # Login to FreeSWITCH and starts grab events.
    def connect(timeout : Time::Span = 5.seconds)
      if @conn.nil?
        socket = TCPSocket.new(@host, @port, timeout)
        @conn = Connection.new(socket)
      end

      tmp_events = conn.channel_events

      # wait for first event sended by freeswitch
      event = receive_timeout(tmp_events, timeout)
      return false if event.nil?
      conn.remove_channel_event(tmp_events)

      # we expect a auth request
      if event.headers["content-type"] != "auth/request"
        conn.close
        return false
      end

      # authenticate
      begin
        resp = if @user.nil?
                 conn.block_send("auth #{@pass}")
               else
                 conn.block_send("userauth #{@user}:#{@pass}")
               end

        if resp == "+OK accepted"
          true
        end
      rescue WaitError
        conn.close
        false
      end
    end

    # Allows to receive events of FreeSWITCH see `events`
    def events
      conn.channel_events
    end

    private def conn
      if @conn.nil?
        raise "connection not started"
      end

      @conn.as(Connection)
    end

    private def receive_timeout(events, timeout : Time::Span) : Event?
      select
      when event = events.receive
        event
      when timeout timeout
        return nil
      end
    end
  end
end
