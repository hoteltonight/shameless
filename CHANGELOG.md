### Unreleased

* Add `Configuration#create_table_options`
* Include shard in underlying index name

### 0.3.1 (2016-11-18)

* Use more static names for underlying database indices
* Use database-portable data types for index columns

### 0.3.0 (2016-11-18)

* Add `Cell#uuid`
* Add `Cell#id`
* Add `Model.fetch_latest_cells`
* Initialize `ref_key` with zero, not one
* Add `Model#present?` and `Cell#present?`
* Allow `Cell#save` to be called even without making any changes
* Add `Model#fetch` and `Cell#fetch`
* Add `Model#reload` and `Cell#reload`
* Add `Model#previous` and `Cell#previous`
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
