require "socket"
require "uri"

module Freeswitch::ESL
  alias Header = Hash(String, String | Int64 | Array(String | Int64))

  class WaitError < Exception
  end

  class ReadEventError < Exception
  end

  class Event
    getter headers
    getter body

    def initialize(@headers : Header, @body : String)
    end

    def message : Header
      if @headers["content-type"] == "text/event-json"
        return Header.from_json(@body).transform_values do |value|
          if value.is_a?(String)
            begin
              URI.decode(value)
            rescue
              value
            end
          else
            value
          end
        end
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
    @running = true
    @events = [] of Channel(Event)

    def initialize(@conn : IO, spawn_receiver = true)
      setup_hooks

      if spawn_receiver
        receive_events()
      end
    end

    def set_events(name : String)
      block_send("event json #{name}")
    end

    def run
      loop do
        break if !@running
        event = receive_event
        if event.nil?
          raise ReadEventError.new
        end

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

    def api(app, arg = nil, timeout : Time::Span = 5.seconds)
      msg = "api #{app}"
      if arg
        msg += " #{arg}"
      end

      response = ApiResponse.new

      @send_mutex.synchronize do
        @api_response.send response
        send(msg)
      end

      wait_for(response, timeout)
    end

    def channel_events
      # correct buffer?
      channel = Channel(Event).new(1024*16)
      @events << channel
      channel
    end

    def remove_channel_event(channel)
      @events.delete(channel)
      channel.close
    end

    def close
      @running = true
      sleep 1.seconds
      conn.close
    end

    def force_close
      @events.each do |ch|
        ch.close
      end
      conn.close
    end

    def send(cmd)
      conn.write("#{cmd}\n\n".encode("utf-8"))
    end

    def block_send(cmd, timeout : Time::Span = 5.seconds)
      responser = CommandResponse.new

      @send_mutex.synchronize do
        @command_response.send responser
        send(cmd)
      end

      wait_for(responser, timeout)
    end

    def execute(app, arg = nil, uuid = nil, event_lock = false, timeout = 5.seconds)
      headers = {"execute-app-name" => app}
      if !arg.nil?
        headers["execute-app-arg"] = arg
      end

      if event_lock
        headers["event-lock"] = "true"
      end

      responser = CommandResponse.new
      @send_mutex.synchronize do
        @command_response.send responser
        sendmsg(uuid, "execute", headers, "")
      end

      wait_for(responser, timeout)
    end

    private def receive_events
      started = Channel(Bool).new

      spawn(name: "receive_events") do
        started.send true
        run()
      rescue ex : Exception
        raise ex
      ensure
        force_close()
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
          content_length = headers.fetch("content-length", "0").as(String).to_i
          if content_length > 0
            body = conn.read_string(content_length)
          end

          return Event.new(headers, body)
        end

        key, value = line.split(":", 2)
        headers[key.downcase] = value.strip
      end

      sleep 1.second
    end

    def sendmsg(uuid, command, headers, body = "")
      # https://freeswitch.org/confluence/display/FREESWITCH/mod_event_socket#sendmsg
      # more details
      msg = String.build do |str|
        if !uuid.nil?
          str << "sendmsg #{uuid}\n"
        else
          str << "sendmsg\n"
        end

        str << "call-command: #{command}\n"
        headers.each do |key, value|
          str << "#{key}: #{value}\n"
        end

        if body != ""
          str << "\n\n#{body}"
        end
        str << "\n"
      end

      Log.debug { msg }
      conn.write(msg.encode("utf-8"))
    end

    private def conn
      if @conn.nil?
        raise "connection not started"
      end
      @conn.as(IO)
    end

    private def wait_for(ch, timeout)
      select
      when response = ch.receive
        response
      when timeout timeout
        raise WaitError.new
      end
    end
  end
end
