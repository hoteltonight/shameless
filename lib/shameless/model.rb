require 'msgpack'
require 'shameless/index'

module Shameless
  module Model
    BASE = "base"

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
      # TODO use uuid from values if present
      uuid = SecureRandom.uuid

      model_values = {
        uuid: uuid,
        column_name: BASE,
        ref_key: 1,
        body: serialize_body(values),
        created_at: Time.now # TODO does the db fill this in anyway?
      }

      shardable_value = uuid[0, 4].to_i(16)
      @store.put(table_name, shardable_value, model_values)

      index_values = values.merge(uuid: uuid)
      @indices.each {|i| i.put(index_values) }

      new(uuid)
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

    def where(query)
      primary_index.where(query).map {|r| new(r[:uuid]) }
    end

    private

    def primary_index
      @indices.find(&:primary?)
    end

    module InstanceMethods
      attr_reader :uuid

      def initialize(uuid)
        @uuid = uuid
      end
    end
  end
end
