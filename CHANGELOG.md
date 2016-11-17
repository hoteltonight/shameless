### Unreleased

* `Model.put` now correctly looks up and updates an existing instance
* Add `Model#update` and `Cell#update`
* Expose `Model#base`
* Add `Configuration#legacy_created_at_is_bigint`
* Keep a reference to only one model class per table name
* Make `Store#find_shard` public
* Make `Store#each_shard` public
* Name index tables `*_:name_index_*`
* Add `Configuration#database_extensions`, they're being passed to the Sequel adapter
* Add `Configuration#connection_options`, they're being passed to the Sequel adapter
* Don't prefix table names with underscore when store name is `nil`
* Add `Store#each_partition`
* Add `Store#disconnect`

### 0.2.0 (2016-11-14)

* Add `Store#padded_shard` to get the formatted shard number for a shardable value

### 0.1.0 (2016-10-14)

* Initial release
