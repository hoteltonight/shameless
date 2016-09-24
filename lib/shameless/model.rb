require 'msgpack'
require 'shameless/index'

module Shameless
  module Model
    BASE = 'base'

    attr_reader :store

    def attach_to(store, name)
      @store = store
      @name = name || self.name.downcase # TODO use activesupport?

      include(InstanceMethods)
    end

    def index(name = nil, &block)
      @indices ||= []
      @indices << Index.new(name, self, &block)
    end

    def put(values)
      uuid = SecureRandom.uuid

      model_values = {
        uuid: uuid,
        column_name: BASE,
        ref_key: 1,
        body: serialize_body(values),
        created_at: Time.now # TODO does the db fill this in anyway?
      }

      shardable_value = shardable_value_from_uuid(uuid)
      @store.put(table_name, shardable_value, model_values)

      index_values = values.merge(uuid: uuid)
      @indices.each {|i| i.put(index_values) }

      new(model_values)
    end

    def update(values, meta_attributes)
      meta_attributes[:ref_key] += 1
      meta_attributes[:body] = serialize_body(values)

      shardable_value = shardable_value_from_uuid(meta_attributes[:uuid])
      @store.put(table_name, shardable_value, meta_attributes)
    end

    def table_name
      "#{@store.name}_#{@name}"
    end

    def create_tables!
      @store.create_table!(table_name) do |t|
        t.primary_key :id
        t.varchar :uuid, size: 36
        t.varchar :column_name, null: false
        t.integer :ref_key, null: false
        t.mediumblob :body
        t.datetime :created_at, null: false

        t.index %i[uuid column_name ref_key], unique: true
      end

      @indices.each(&:create_tables!)
    end

    def serialize_body(values)
      MessagePack.pack(values)
    end

    def deserialize_body(body)
      MessagePack.unpack(body)
    end

    def where(query)
      primary_index.where(query).map {|r| new(r) }
    end

    def fetch_column(uuid, column)
      shardable_value = shardable_value_from_uuid(uuid)
      query = {uuid: uuid, column_name: column}

      @store.where(table_name, shardable_value, query).order(:ref_key).last
    end

    private

    def primary_index
      @indices.find(&:primary?)
    end

    def shardable_value_from_uuid(uuid)
      uuid[0, 4].to_i(16)
    end

    module InstanceMethods
      def initialize(meta_attributes)
        @meta_attributes = meta_attributes
      end

      def [](field)
        body[field.to_s]
      end

      def []=(field, value)
        body[field.to_s] = value
      end

      def save
        self.class.update(body, @meta_attributes)
      end

      def uuid
        @meta_attributes[:uuid]
      end

      private

      def body
        @body ||= self.class.deserialize_body(base[:body])
      end

      def base
        @base ||= fetch_column(BASE)
      end

      def fetch_column(column)
        self.class.fetch_column(uuid, column)
      end
    end
  end
end
