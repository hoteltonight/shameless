module Shameless
  class Index
    PRIMARY = :primary

    def initialize(name, model, &block)
      @name = name || PRIMARY
      @model = model
      instance_eval(&block)
    end

    DataTypes = %i[integer string]

    DataTypes.each do |type|
      define_method(type) do |column|
        self.column(column, type)
      end
    end

    def column(name, type)
      @columns ||= {}
      @columns[name] = type
    end

    def shard_on(shard_on)
      @shard_on = shard_on
    end

    def put(values)
      shardable_value = values.fetch(@shard_on)
      index_values = (@columns.keys + [:uuid]).each_with_object({}) {|column, o| o[column] = values.fetch(column) }

      @model.store.put(table_name, shardable_value, index_values)
    end

    def table_name
      "#{@model.table_name}_#{@name}"
    end

    def create_tables!
      @model.store.create_table!(table_name) do |t|
        t.varchar :uuid, size: 36

        @columns.each do |name, type|
          t.column name, type, null: false
        end
      end
    end

    def primary?
      @name == PRIMARY
    end

    def where(query)
      shardable_value = query.fetch(@shard_on)
      @model.store.where(table_name, shardable_value, query)
    end
  end
end
