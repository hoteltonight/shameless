require 'shameless/errors'

module Shameless
  class Index
    PRIMARY = :primary

    attr_reader :name

    def initialize(name, model, &block)
      @name = name || PRIMARY
      @model = model
      instance_eval(&block)
    end

    DataTypes = {integer: Integer, string: String}

    DataTypes.each do |name, type|
      define_method(name) do |column|
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
      index_values = index_values(values, true)

      @model.store.put(table_name, shardable_value, index_values)
    end

    def where(query)
      shardable_value = query.fetch(@shard_on)
      query = index_values(query, false)
      @model.store.where(table_name, shardable_value, query).map {|r| @model.new(r[:uuid]) }
    end

    def table_name
      "#{@model.table_name}_#{full_name}"
    end

    def full_name
      "#{@name}_index"
    end

    def index_values(values, all_required)
      (@columns.keys + [:uuid]).each_with_object({}) do |column, o|
        if all_required
          o[column] = values.fetch(column)
        else
          o[column] = values[column] if values.key?(column)
        end
      end
    end

    def create_tables!
      @model.store.create_table!(table_name) do |t, sharded_table_name|
        @columns.each do |name, type|
          t.column name, type, null: false
        end

        t.varchar :uuid, size: 36

        t.index @columns.keys, name: "#{sharded_table_name}_index", unique: true
      end
    end

    def column?(key)
      @columns.keys.any? {|c| c.to_s == key.to_s }
    end

    def prevent_readonly_attribute_mutation!(key)
      if column?(key)
        raise ReadonlyAttributeMutation, "The attribute #{key} cannot be modified because it's part of the #{@name} index"
      end
    end
  end
end
