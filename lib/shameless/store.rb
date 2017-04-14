require 'sequel'
require 'shameless/configuration'
require 'shameless/model'

module Shameless
  class Store
    attr_reader :name, :configuration

    def initialize(name, &block)
      @name = name
      @configuration = Configuration.new
      block.call(@configuration)
    end

    def attach(model_class, name = nil)
      model_class.extend(Model)
      model_class.attach_to(self, name)
      models_hash[name] = model_class
    end

    def put(table_name, shardable_value, values)
      find_table(table_name, shardable_value).insert(values)
    end

    def where(table_name, shardable_value, query, &block)
      find_table(table_name, shardable_value).where(query, &block)
    end

    def disconnect
      if instance_variable_defined?(:@partitions)
        partitions.each(&:disconnect)
      end
    end

    def each_partition(&block)
      partitions.each do |partition|
        block.call(partition, table_names_on_partition(partition))
      end
    end

    def create_tables!
      models.each(&:create_tables!)
    end

    def create_table!(table_name, &block)
      each_shard do |shard|
        partition = find_partition_for_shard(shard)
        sharded_table_name = table_name_with_shard(table_name, shard)
        options = @configuration.create_table_options || {}
        partition.create_table(sharded_table_name, options) { block.call(self, sharded_table_name) }
      end
    end

    def padded_shard(shardable_value)
      shard = find_shard(shardable_value)
      format_shard(shard)
    end

    def each_shard(&block)
      0.upto(@configuration.shards_count - 1, &block)
    end

    def find_shard(shardable_value)
      shardable_value % @configuration.shards_count
    end

    private

    def models_hash
      @models_hash ||= {}
    end

    def models
      models_hash.values
    end

    def partitions
      @partitions ||= @configuration.partition_urls.map {|url| connect(url) }
    end

    def connect(url)
      Sequel.connect(url, @configuration.connection_options || Sequel::OPTS).tap do |db|
        db.extension(*@configuration.database_extensions)
      end
    end

    def table_names_on_partition(partition)
      partition_index = partitions.index(partition)
      first_shard = partition_index * @configuration.shards_per_partition_count
      last_shard = first_shard + @configuration.shards_per_partition_count - 1
      shards = first_shard..last_shard
      table_names = models.flat_map(&:table_names)

      table_names.flat_map {|t| shards.map {|s| table_name_with_shard(t, s) } }
    end

    def table_name_with_shard(table_name, shard)
      padded_shard = format_shard(shard)
      "#{table_name}_#{padded_shard}"
    end

    def format_shard(shard)
      shard.to_s.rjust(6, '0')
    end

    def find_table(table_name, shardable_value)
      shard = find_shard(shardable_value)
      partition = find_partition_for_shard(shard)
      table_name = table_name_with_shard(table_name, shard)
      partition.from(table_name)
    end

    def find_partition_for_shard(shard)
      partition_index = shard / @configuration.shards_per_partition_count
      partitions[partition_index]
    end
  end
end
