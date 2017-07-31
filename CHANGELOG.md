### Unreleased

### 0.6.1 (2017-07-31)

* Fix Sequel deprecation warning

### 0.6.0 (2017-07-26)

* Require `securerandom` explicitly
* Add support for queries using Sequel's virtual rows

### 0.5.2 (2016-12-02)

* Eagerly initialize `Model#cells`

### 0.5.1 (2016-12-01)

* Convert shardable value to integer for index tables

### 0.5.0 (2016-12-01)

* Add `Model#as_json` and `Cell#as_json`
* Remember cell ID after save

### 0.4.0 (2016-11-21)

* `Model#reload` now reloads all cells
* Add `Model#cells`
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
