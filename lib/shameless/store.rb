require 'sequel'
require 'shameless/configuration'
require 'shameless/model'

module Shameless
  class Store
    attr_reader :name

    def initialize(name, &block)
      @name = name
      @configuration = Configuration.new
      block.call(@configuration)
    end

    def attach(model_class, name = nil)
      model_class.extend(Model)
      model_class.attach_to(self, name)
      @models ||= []
      @models << model_class
    end

    def put(table_name, shardable_value, values)
      find_table(table_name, shardable_value).insert(values)
    end

    def where(table_name, shardable_value, query)
      find_table(table_name, shardable_value).where(query)
    end

    def create_tables!
      @models.each(&:create_tables!)
    end

    def create_table!(table_name, &block)
      each_shard do |shard|
        partition = find_partition_for_shard(shard)
        sharded_table_name = table_name_with_shard(table_name, shard)
        partition.create_table(sharded_table_name) { block.call(self) }
      end
    end

    def padded_shard(shardable_value)
      shard = find_shard(shardable_value)
      format_shard(shard)
    end

    private

    def partitions
      @partitions ||= @configuration.partition_urls.map {|url| Sequel.connect(url) }
    end

    def each_shard(&block)
      0.upto(@configuration.shards_count - 1, &block)
    end

    def table_name_with_shard(table_name, shard)
      padded_shard = format_shard(shard)
      "#{table_name}_#{padded_shard}"
    end

    def format_shard(shard)
      shard.to_s.rjust(6, '0')
    end

    def find_shard(shardable_value)
      shardable_value % @configuration.shards_count
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
