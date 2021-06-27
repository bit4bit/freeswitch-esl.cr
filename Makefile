.PHONY: test fs_cli.cr outbound.cr

samples: fs_cli.cr outbound.cr

fs_cli.cr: samples/fs_cli.cr
	shards build fs_cli.cr

outbound.cr: samples/outbound.cr
	shards build outbound.cr

test:
	crystal spec
