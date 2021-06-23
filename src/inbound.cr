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
