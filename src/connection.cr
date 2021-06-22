require "socket"

module Freeswitch::ESL
  alias Header = Hash(String, String | Int64)

  class Event
    getter headers
    getter body

    def initialize(@headers : Header, @body : String)
    end

    def message : Header
      if @headers["content-type"] == "text/event-json"
        return Header.from_json(@body)
      end

      Header.new
    end
  end

  class Connection
    @api_response = Channel(String).new
    @hooks = [] of NamedTuple(key: String, value: String, call: (Event -> Void))

    @events = [] of Channel(Event)

    def initialize(@conn : IO)
      @debug = File.new("/tmp/sale", "w")

      setup_hooks
      receive_events()
    end

    def set_events(name : String)
      send("event json #{name}")
    end

    def api(app, arg = nil)
      msg = "api #{app}"
      if arg
        msg += " #{arg}"
      end

      send(msg)
      @api_response.receive
    end

    def channel_events
      channel = Channel(Event).new
      @events << channel
      channel
    end

    def close
      conn.close
    end

    def send(cmd)
      Log.info { "send: #{cmd}" }
      conn.write("#{cmd}\n\n".encode("utf-8"))
    end

    private def receive_events
      started = Channel(Bool).new

      spawn do
        started.send true

        loop do
          event = receive_event

          @hooks.each do |hook|
            if event.headers.fetch(hook[:key], nil) == hook[:value]
              hook[:call].call(event)
            end
          end

          @events.each do |channel|
            select
            when channel.send event
            else
            end
          end
        end
      end

      started.receive
    end

    private def setup_hooks
      hook("content-type", "api/response") do |event|
        @api_response.send event.body
      end
    end

    private def hook(key, value, &block : Event -> Void)
      @hooks << {key: key, value: value, call: block}
    end

    private def receive_event
      headers = Header.new
      body = ""
      conn.each_line(chomp: true) do |line|
        @debug.puts line
        @debug.flush

        if line == ""
          content_length = headers.fetch("content-length", "0").to_i
          if content_length > 0
            body = conn.read_string(content_length)
            @debug.write body.encode("utf-8")
            @debug.flush
          end

          return Event.new(headers, body)
        end

        key, value = line.split(":", 2)
        headers[key.downcase] = value.strip
      end

      raise "unexpected"
    end

    def execute(app, arg = nil, uuid = nil, async = false)
      if !uuid.nil?
        msg = "sendmsg #{uuid}\n"
      else
        msg = "sendmsg\n"
      end

      msg += "call-command: execute\n"
      msg += "execute-app-name: #{app}\n" if app
      msg += "execute-app-arg: #{arg}\n" if arg
      msg += "event-lock: true\n"
      if async
        msg += "async: true\n"
      end
      msg += "\n"

      Log.info { "execute: #{msg}" }
      conn.write(msg.encode("utf-8"))
    end

    private def conn
      if @conn.nil?
        raise "connection not started"
      end
      @conn.as(IO)
    end
  end
end
