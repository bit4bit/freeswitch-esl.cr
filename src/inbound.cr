require "socket"
require "log"
require "json"

module Freeswitch::ESL
  class Inbound
    @conn : Connection?
    @events = Channel(Event).new

    def initialize(@host : String, @port : Int32, @pass : String, @user : String? = nil)
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
    end

    def sendevent(event, headers : Hash(String, String | Int64) = {} of String => String | Int64, body = "")
      content_length = body.size
      headers = headers.clone
      headers["content-length"] = content_length
      headers_msg = headers.each { |k, v| "#{k}: #{v}" }
      lines = ["sendevent #{event}"].concat(headers_msg).join("\n")

      if content_length == 0
        block_send "#{lines}"
      else
        block_send "#{lines}\n\n#{body}"
      end
    end

    def connect(timeout : Time::Span)
      socket = TCPSocket.new(@host, @port, timeout)
      @conn = Connection.new(socket)

      spawn do
        events = conn.channel_events
        loop do
          @events.send events.receive
        end
      end

      event = receive_timeout(timeout)
      return false if event.nil?

      if event.headers["content-type"] != "auth/request"
        conn.close
        return false
      end

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

    private def receive_timeout(timeout : Time::Span) : Event?
      select
      when event = @events.receive
        event
      when timeout timeout
        return nil
      end
    end
  end
end
