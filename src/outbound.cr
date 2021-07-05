require "socket"

module Freeswitch::ESL
  class Outbound

    def initialize(@conn : Connection)
    end

    def execute(app, arg = nil, event_lock = false)
      @conn.execute(app, arg, event_lock: event_lock)
    end

    def self.listen(host : String, port : Int32, &block : (Outbound, Channel(Event)) -> _)
      server = TCPServer.new(host, port)
      spawn run(server, block)

      return server.local_address
    end

    private def self.run(server, block : (Outbound, Channel(Event)) -> _)
      spawn do
        loop do
          if socket = server.accept?
            spawn handle_connection(socket, block)
          else
            break
          end
        end
      end
    end

    private def self.handle_connection(socket, block)
      conn = Connection.new(socket)
      events = conn.channel_events      

      # handshake
      conn.send("connect")

      # run user application
      block.call(new(conn), events)

      # close connection
      # TODO(bit4bit) graceful close?
      # conn.close
      # socket.close
    end
  end
end
