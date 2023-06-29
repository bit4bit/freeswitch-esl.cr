require "socket"

module Freeswitch::ESL
  # Handle connections from FreeSWITCH `socket` application
  # mainly use for taking control of calls.
  class Outbound
    def self.listen(host : String, port : Int32, &block : (Outbound, Channel(Event)) -> _)
      server = TCPServer.new(host, port)
      spawn run(server, block)

      server.local_address
    end

    # execute applications in the handled call
    def execute(app, arg = nil, event_lock = false)
      @conn.execute(app, arg, event_lock: event_lock)
    end

    private def initialize(@conn : Connection)
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

      # close
      conn.close
    end
  end
end
