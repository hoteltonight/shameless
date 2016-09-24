# Shameless

Shameless is an implementation of a schemaless, distributed, append-only store built on top of MySQL and the Sequel gem. It was extracted from a battle-tested codebase of our main application at HotelTonight. Since it's using Sequel for database access, it could work on any database, e.g. postgres, although we've only used it with MySQL.

## Concept

Shameless was born out of our need to have highly scalable, distributed storage for hotel rates. Rates are a way hotels package their rooms, they typically include check-in and check-out date, room type, rate plan, net price, discount, extra services, etc. Our original solution of storing rates in a typical relational SQL table was reaching its limits due to write congestion, migration anxiety, and high maintenance.

Hotel rates change very frequently, so our solution needed to have consistent write latency. There are also mutliple agents mutating various aspects of those rates, so we wanted something that would enable versioning. We also wanted to avoid having to create migrations whenever we were adding more data to rates.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'shameless'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install shameless

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/hoteltonight/shameless.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
