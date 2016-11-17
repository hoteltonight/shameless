require 'shameless/index'
require 'shameless/cell'

module Shameless
  module Model
    attr_reader :store

    def attach_to(store, name)
      @store = store
      @name = name || self.name.downcase # TODO use activesupport?

      include(InstanceMethods)
    end

    def index(name = nil, &block)
      @indices ||= []
      index = Index.new(name, self, &block)
      @indices << index

      define_singleton_method(index.full_name) { index }
    end

    def cell(name)
      name = name.to_s

      define_method(name) do
        @cells ||= {}
        @cells[name] ||= Cell.new(self, name)
      end
    end

    def put(values)
      if model = where(values).first
        model_values = reject_index_values(values)
        model.update(model_values)
        model
      else
        uuid = SecureRandom.uuid

        new(uuid, values).tap do |model|
          model.save

          index_values = values.merge(uuid: uuid)
          @indices.each {|i| i.put(index_values) }
        end
      end
    end

    def put_cell(shardable_value, cell_values)
      @store.put(table_name, shardable_value, cell_values)
    end

    def fetch_cell(shardable_value, uuid, cell_name)
      query = {uuid: uuid, column_name: cell_name}

      @store.where(table_name, shardable_value, query).order(:ref_key).last
    end

    def table_name
      [@store.name, @name].compact.join('_')
    end

    def table_names
      [table_name, *@indices.map(&:table_name)]
    end

    def create_tables!
      @store.create_table!(table_name) do |t|
        t.primary_key :id
        t.varchar :uuid, size: 36
        t.varchar :column_name, null: false
        t.integer :ref_key, null: false
        t.mediumblob :body

        created_at_type = @store.configuration.legacy_created_at_is_bigint ? :bigint : :datetime
        t.column :created_at, created_at_type, null: false

        t.index %i[uuid column_name ref_key], unique: true
      end

      @indices.each(&:create_tables!)
    end

    def where(query)
      primary_index.where(query)
    end

    def reject_index_values(values)
      values.reject {|k, _| @indices.any? {|i| i.column?(k) } }
    end

    def prevent_readonly_attribute_mutation!(key)
      @indices.each {|i| i.prevent_readonly_attribute_mutation!(key) }
    end

    private

    module InstanceMethods
      attr_reader :uuid, :base

      def initialize(uuid, base_body = nil)
        @uuid = uuid
        @base = Cell.base(self, base_body)
      end

      def [](field)
        @base[field]
      end

      def []=(field, value)
        @base[field] = value
      end

      def update(values)
        @base.update(values)
      end

      def save
        @base.save
      end

      def ref_key
        @base.ref_key
      end

      def created_at
        @base.created_at
      end

      def put_cell(cell_values)
        self.class.put_cell(shardable_value, cell_values)
      end

      def fetch_cell(cell_name)
       self.class.fetch_cell(shardable_value, uuid, cell_name)
      end

      def prevent_readonly_attribute_mutation!(key)
        self.class.prevent_readonly_attribute_mutation!(key)
      end

      private

      def shardable_value
        uuid[0, 4].to_i(16)
      end
    end
  end
end
