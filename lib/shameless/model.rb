require 'securerandom'
require 'shameless/index'
require 'shameless/cell'

module Shameless
  module Model
    attr_reader :store

    def attach_to(store, name)
      @store = store
      @name = name || self.name.downcase # TODO use activesupport?
      @cell_names = []
      cell(Cell::BASE)

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
      @cell_names << name

      define_method(name) { @cells[name] }
    end

    def initialize_cells(instance, base_body)
      Hash[@cell_names.map do |name|
        cell = name == Cell::BASE ? Cell.base(instance, base_body) : Cell.new(instance, name)
        [name, cell]
      end]
    end

    def put(values)
      if model = where(values).first
        model_values = reject_index_values(values)
        model.update(model_values)
        model
      else
        uuid = SecureRandom.uuid

        new(uuid, values).tap do |m|
          m.save

          index_values = values.merge(uuid: uuid)
          @indices.each {|i| i.put(index_values) }
        end
      end
    end

    def put_cell(shardable_value, cell_values)
      @store.put(table_name, shardable_value, cell_values)
    end

    def fetch_cell(shardable_value, uuid, cell_name, ref_key)
      query = {uuid: uuid, column_name: cell_name}
      query[:ref_key] = ref_key if ref_key

      @store.where(table_name, shardable_value, query).order(:ref_key).last
    end

    def fetch_latest_cells(shard:, cursor:, limit:)
      query = Sequel.lit("id > ?", cursor)
      @store.where(table_name, shard, query).limit(limit).map do |cell_values|
        model = new(cell_values[:uuid])
        name = cell_values[:column_name].to_sym
        Cell.new(model, name, cell_values)
      end
    end

    def max_id_on_shard(shard)
      @store.find_table(table_name, shard).max(:id)
    end

    def table_name
      [@store.name, @name].compact.join('_')
    end

    def table_names
      [table_name, *@indices.map(&:table_name)]
    end

    def create_tables!
      @store.create_table!(table_name) do |t, sharded_table_name|
        t.primary_key :id
        t.varchar :uuid, size: 36
        t.varchar :column_name, null: false
        t.integer :ref_key, null: false
        t.mediumblob :body

        created_at_type = @store.configuration.legacy_created_at_is_bigint ? :bigint : :datetime
        t.column :created_at, created_at_type, null: false

        t.index %i[uuid column_name ref_key], name: "#{sharded_table_name}_model", unique: true
      end

      @indices.each(&:create_tables!)
    end

    def where(query, &block)
      primary_index.where(query, &block)
    end

    def reject_index_values(values)
      values.reject {|k, _| @indices.any? {|i| i.column?(k) } }
    end

    def prevent_readonly_attribute_mutation!(key)
      @indices.each {|i| i.prevent_readonly_attribute_mutation!(key) }
    end

    private

    module InstanceMethods
      attr_reader :uuid

      def initialize(uuid, base_body = nil)
        @uuid = uuid
        @cells = self.class.initialize_cells(self, base_body)
      end

      def [](field)
        base[field]
      end

      def []=(field, value)
        base[field] = value
      end

      def update(values)
        base.update(values)
      end

      def save
        base.save
      end

      def ref_key
        base.ref_key
      end

      def created_at
        base.created_at
      end

      def previous
        base.previous
      end

      def fetch(key, default)
        base.fetch(key, default)
      end

      def present?
        base.present?
      end

      def as_json(*)
        base.as_json
      end

      def reload
        cells.each(&:reload)
      end

      def cells
        @cells.values
      end

      def put_cell(cell_values)
        self.class.put_cell(shardable_value, cell_values)
      end

      def fetch_cell(cell_name, ref_key = nil)
       self.class.fetch_cell(shardable_value, uuid, cell_name, ref_key)
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
