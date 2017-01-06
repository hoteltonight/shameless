# Shameless

[![Build Status](https://travis-ci.org/hoteltonight/shameless.svg?branch=master)](https://travis-ci.org/hoteltonight/shameless)

Shameless is an implementation of a schemaless, distributed, append-only store built on top of MySQL and the Sequel gem. It was extracted from a battle-tested codebase of our main application at HotelTonight. Since it's using Sequel for database access, it could work on any database, e.g. postgres, although we've only used it with MySQL.

## Background

Shameless was born out of our need to have highly scalable, distributed storage for hotel rates. Rates are a way hotels package their rooms, they typically include check-in and check-out date, room type, rate plan, net price, discount, extra services, etc. Our original solution of storing rates in a typical relational SQL table was reaching its limits due to write congestion, migration anxiety, and high maintenance.

Hotel rates change very frequently, so our solution needed to have consistent write latency. There are also multiple agents mutating various aspects of those rates, so we wanted something that would enable versioning. We also wanted to avoid having to create migrations whenever we were adding more data to rates.

## Concept

The whole idea of Shameless is to split a regular SQL table into index tables and content tables. Index tables map the fields you want to query by to UUIDs, content tables map UUIDs to model contents (bodies). In addition, both index and content tables are sharded.

The body of the model is schema-less, you can store arbitrary data structures in it. Under the hood, the body is serialized using MessagePack and stored as a blob in a single database column (hence the need for index tables).

The process of querying for records can be described as:

1. Query the index tables by index fields (e.g. hotel ID, check-in date, and length of stay), sharded by hotel ID, getting get back a list of UUIDs
1. Query the content tables, sharded by UUID, for most recent version of model

Inserting a record is similar:

1. Generate a UUID
1. Serialize and write model content into appropriate shard of the content tables
1. Insert a row (index fields + model UUID) to the appropriate shard of the index table

Inserting a new version of an existing record is even simpler:

1. Increment version
1. Serialize and write model content into appropriate shard of the content tables

Naturally, shameless hides all that complexity behind a straight-forward API.

## Usage

### Creating a store

The core object of shameless is a `Store`. Here's how you can set one up:

```ruby
# config/initializers/rate_store.rb

RateStore = Shameless::Store.new(:rate_store) do |c|
  c.partition_urls = [ENV['RATE_STORE_DATABASE_URL_0'], ENV['RATE_STORE_DATABASE_URL_1']
  c.shards_count = 512 # total number of shards across all partitions
  c.connection_options = {max_connections: 10} # connection options passed to `Sequel.connect`
  c.database_extensions = [:newrelic_instrumentation]
  c.create_table_options = {engine: "InnoDB"} # passed to Sequel's `create_table`
end
```

The initializer argument (`:rate_store`) defines the namespace by which all tables will be prefixed, in this case `rate_store_`. If you pass `nil`, there will be no prefix.

Once you've got the Store configured, you can declare models.

### Declaring models

Models specify the kinds of entities you want to persist in your store. Models are simple Ruby classes (even anonymous) that you attach to a `Store` using `Store#attach(model)`, e.g.:

```ruby
# app/models/rate.rb

class Rate
  RateStore.attach(self)

  # ...
end
```

By default, this will map to tables called `rate_store_rate_[000000-000511]` by lowercasing the class name. You can also provide the table namespace using a second argument, e.g.:

```ruby
my_model = Class.new do
  RateStore.attach(self, :rates)
end
```

A model is useless without indices. Let's see how to define them.

### Defining indices

Indices are a crucial component of shameless. They allow us to perform fast lookups for model UUIDs. Here's how you define an index:

```ruby
class Rate
  RateStore.attach(self)

  index do
    integer :hotel_id
    string :room_type
    string :check_in_date # at the moment, only integer and string types are supported

    shard_on :hotel_id # required, values need to be numeric
  end
end
```

The default index is called a primary index, the corresponding tables would be called `rate_store_rate_primary_index_[000000-000511]`. You can add additional indices you'd like to query by:

```ruby
class Rate
  RateStore.attach(self)

  index do
    # ..
  end

  index :secondary do
    integer :hotel_id
    string :gateway
    string :discount_type

    shard_on :hotel_id
  end
end
```

### Defining cells

Model content is stored in blobs called "cells". You can think of cells as separate model columns that can store rich data structures and can change independently over time. The default cell is called "base" (that's what all model-level accessors delegate to), but you can declare additional cells using `Model.cell`:

```ruby
class Rate
  RateStore.attach(self)

  index do
    # ..
  end

  cell :meta
end
```

### Reading/writing

To write data to the model, use `Model.put` `Model#save`, `Cell#save`, `Model#update`, or `Cell#update`. `Model.put` will perform an "upsert", i.e. it will try to find an existing record with the given index fields, and insert a new version for that record's base cell if it finds one, or pick a new UUID, write the first version of the base cell, and write to all indices otherwise.

Here are some examples of how you can read and write data from/to a shameless store:

```ruby
# Writing - all index fields are required, the rest is the schemaless content
rate = Rate.put(hotel_id: 1, room_type: '1 bed', check_in_date: Date.today, gateway: 'pegasus', discount_type: 'geo', net_price: 120.0)
rate[:net_price] # => 120.0 # access in the "base" cell

# Create a new version of the "base" cell
rate[:net_price] = 130.0
rate.save

# You can also access the "base" cell explicitly
rate.base[:net_price] = 140.0
rate.base.save

# Reading from/writing to a different cell is simple, too:
rate.meta[:hotel_enabled] = true
rate.meta.save

# You can also do that in one go using `Model#update` or `Cell#update`. This writes a new
# version of the cell, merging the hash passed in as parameter with existing values.
rate.update(tax_rate: 11.0, gateway: 'pegasus')
rate.body # => {net_price: 140.0, tax_rate: 11.0, gateway: 'pegasus'}

rate.meta.update(hotel_enabled: false)
```

To query, use `Model.where`:

```ruby
# Querying by primary index
rates = Rate.where(hotel_id: 1, room_type: '1 bed', check_in_date: Date.today)

# Querying by a named index
rates = Rate.secondary_index.where(hotel_id: 1, gateway: 'pegasus', discount_type: 'geo')
rates.first[:net_price] # => 130.0
```

To access a cell field that you're not sure has a value, you can use and `Cell#fetch` (`Model#fetch` delegates to the base cell) to get a value from a cell, or a default, e.g.:

```ruby
rate[:net_price] = 130.0
rate.fetch(:net_price, 100) # => 130.0
rate.meta.fetch(:enabled, true) # => true
```

Cells are versioned, the current version is stored in a column called `ref_key`. The first version of a cell has a `ref_key` of zero. To access a previous version of a cell, use `Cell#previous` (`Model#previous` delegates to the base cell). Example:

```ruby
# ...
rate[:net_price] # => 120.0
rate.ref_key # => 1
rate.update(net_price: 130.0)
rate.ref_key # => 2
rate.previous[:net_price] # => 120.0
rate.previous.ref_key # => 1
rate.previous.previous.ref_key # => 0
rate.previous.previous.previous # => nil
```

It could happen that another process may have updated a model/cell. To fetch the latest state, use `Cell#reload` (`Model#reload` reloads *all* cells), e.g.:

```ruby
rate[:net_price] # => 120.0

# Another process updates the cell
Rate.where(hotel_id: rate[:hotel_id]).first.update(net_price: 130.0)

rate[:net_price] # => 120.0
rate.reload
rate[:net_price] # => 130.0
```

To check if a given cell exists, use `Cell#present?` (as you can suspect, `Model#present?` delegates to the base cell). You can also use `Model#cells` to iterate over all cells, e.g.:

```ruby
rate.present? # => true
rate.meta.present? # => false

rate.cells.any?(&:present?) # => true
```

To see the cell's full state (body + metadata), use `Cell#as_json` (`Model#as_json` delegates to the base cell), e.g.:

```ruby
rate.as_json # => {id: 123, uuid: "...", created_at: "...", column_name: "base", ref_key: 3,
  # body: {hotel_id: 1, check_in_date: "2017-01-03", room_type: "ROH", net_price: 130.0}}
```

### Creating tables

To create all shards for all tables, across all partitions, run:

```ruby
RateStore.create_tables!
```

This will create the underlying index tables, content tables, together with database indices for fast access.

### Concurrent writes

Since writes to shameless aren't atomic, concurrency control needs to be moved to application code. We're using a setup where almost all our writes go through queues, one queue per shard. We're using `Store#each_shard` to match queue names to shards and to aggregate queue stats across all shards.

### Using shameless as a data stream store (similar to Kafka)

Thanks to storing each write to shameless as a new record in the underlying database table, we're able to use our shameless store as a log for stream processing. For each shard, we have a worker that goes through all new entries in that shard and triggers various event processors to handle all kinds of asynchronous work. For that purpose, we're using `Model.fetch_latest_cells(shard:, cursor:, limit:)`, and incrementing a cursor (stored in Redis) after each record has been processed successfully. We're using the cells' IDs as cursors, using `Cell#id`, which returns the underlying table's primary key value.

### Utilities

Sometimes it may be useful to know where a given model will end up, based on its shardable value. For this, you can use `Store#find_shard(shardable_value)`, e.g.: `RateStore.find_shard(hotel.id) # => 196`.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'shameless'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install shameless

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/hoteltonight/shameless.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Credits

Shameless was inspired by the following resources:

- Uber: https://eng.uber.com/schemaless-part-one
- FriendFeed: https://backchannel.org/blog/friendfeed-schemaless-mysql
- Pinterest: https://engineering.pinterest.com/blog/sharding-pinterest-how-we-scaled-our-mysql-fleet
