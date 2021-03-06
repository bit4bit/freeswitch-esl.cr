# freeswitch-esl

Production Ready.

Freeswitch Event Socket library for [Crystal language](https://github.com/crystal-lang/crystal).


## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     freeswitch-esl:
       github: bit4bit/freeswitch-esl.cr
   ```

2. Run `shards install`

## Usage

see directory **samples/**.

## Usage Inbound

```crystal
require "freeswitch-esl"

conn = Freeswitch::ESL::Inbound.new("172.29.0.9", 8021, "ClueCon")
if !conn.connect(1.second)
  puts "failed to login"
end

puts conn.api "uptime"

events = conn.events

spawn do
  loop do
    event = events.receive
    puts event.headers
    puts event.message
  end
end

sleep
```

## Usage Outbound

```crystal
require "freeswitch-esl"

Freeswitch::ESL::Outbound.listen("127.0.0.1", 40000) do |conn, events|
  # first events it's channel data
  channel_data = events.receive
  puts channel_data.headers

  resp = conn.execute "answer"
  puts resp
  conn.execute "hangup"
end
```

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/bit4bit/freeswitch-esl/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Jovany Leandro G.C](https://github.com/bit4bit) - creator and maintainer
