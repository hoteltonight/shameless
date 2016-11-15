### Unreleased

* Add `Configuration#database_extensions`, they're being passed to the Sequel adapter
* Add `Configuration#connection_options`, they're being passed to the Sequel adapter
* Don't prefix table names with underscore when store name is `nil`
* Add `Store#each_partition`
* Add `Store#disconnect`

### 0.2.0 (2016-11-14)

* Add `Store#padded_shard` to get the formatted shard number for a shardable value

### 0.1.0 (2016-10-14)

* Initial release
