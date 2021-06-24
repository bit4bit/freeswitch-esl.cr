require "socket"

module Freeswitch::ESL
  alias Header = Hash(String, String | Int64)

  class WaitError < Exception
  end

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
    alias ApiResponse = Channel(String)
    alias CommandResponse = Channel(String)

    @send_mutex = Mutex.new
    @api_response = Channel(ApiResponse).new(1)
    @command_response = Channel(CommandResponse).new(1)
    @hooks = [] of NamedTuple(key: String, value: String, call: (Event -> Void))

    @events = [] of Channel(Event)

    def initialize(@conn : IO)
      setup_hooks
      receive_events()
    end

    def set_events(name : String)
      block_send("event json #{name}")
    end

    def api(app, arg = nil)
      msg = "api #{app}"
      if arg
        msg += " #{arg}"
      end

      response = ApiResponse.new

      @send_mutex.synchronize do
        @api_response.send response
        send(msg)
      end

      response.receive
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

    def block_send(cmd, timeout : Time::Span = 5.seconds)
      responser = CommandResponse.new

      @send_mutex.synchronize do
        @command_response.send responser
        send(cmd)
      end

      select
      when response = responser.receive
        response
      when timeout timeout
        raise WaitError.new
      end
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
        select
        when responser = @api_response.receive
          responser.send event.body
        else
        end
      end

      hook("content-type", "command/reply") do |event|
        select
        when responser = @command_response.receive
          responser.send event.headers["reply-text"].to_s
        else
        end
      end
    end

    private def hook(key, value, &block : Event -> Void)
      @hooks << {key: key, value: value, call: block}
    end

    private def receive_event
      headers = Header.new
      body = ""
      conn.each_line(chomp: true) do |line|
        if line == ""
          content_length = headers.fetch("content-length", "0").to_i
          if content_length > 0
            body = conn.read_string(content_length)
          end

          return Event.new(headers, body)
        end

        key, value = line.split(":", 2)
        headers[key.downcase] = value.strip
      end

      raise "unexpected"
    end

    def sendmsg(uuid, command, headers, body = "")
      msg = String.build do |str|
        if !uuid.nil?
          str << "sendmsg #{uuid}\n"
        else
          str << "sendmsg\n"
        end

        str << "call-command: #{command}\n"
        headers.each do |key, value|
          str << "#{key}: #{value}"
        end

        if body != ""
          str << "\n\n#{body}"
        end
        str << "\n"
      end

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
