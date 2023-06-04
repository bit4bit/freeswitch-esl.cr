require "socket"
require "json"

module Freeswitch::ESL
  # Public
  class Inbound
    @conn : Connection? = nil

    def initialize(@host : String, @port : Int32, @pass : String, @user : String? = nil)
    end

    def initialize(@conn : Connection, @pass : String, @user : String? = nil)
      @host = ""
      @port = 0
    end

    def api(app, arg = nil)
      conn.api(app, arg)
    end

    def set_events(name : String)
      conn.set_events(name)
    end

    def linger
      conn.block_send("linger")
    end

    def nolinger
      conn.block_send("nolinger")
    end

    def myevents(uuid : String)
      conn.block_send("myevents json #{uuid}")
    end

    def filter(key, value = "")
      conn.block_send("filter #{key} #{value}")
    end

    def filter_delete(key, value = "")
      conn.block_send("filter delete #{key} #{value}")
    end

    def log(level)
      conn.block_send("log #{level}")
    end

    def nolog
      conn.block_send("nolog")
    end

    def nixevent(events : String)
      conn.block_send("nixevent #{events}")
    end

    def noevents
      conn.block_send("noevents")
    end

    def exit
      conn.block_send("exit")
      conn.close
    end

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

      block_send msg
    end

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
