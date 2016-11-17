require 'msgpack'

module Shameless
  class Cell
    BASE = 'base'

    def self.base(model, body)
      new(model, BASE, body: body)
    end

    def initialize(model, name, values = nil)
      @model = model
      @name = name
      @body = stringify_keys(values[:body]) if values
      initialize_from_values(values)
    end

    def [](key)
      body[key.to_s]
    end

    def []=(key, value)
      @model.prevent_readonly_attribute_mutation!(key)
      body[key.to_s] = value
    end

    def save
      load
      @created_at = Time.now
      @created_at = (@created_at.to_f * 1000).to_i if @model.class.store.configuration.legacy_created_at_is_bigint
      @ref_key ||= 0
      @ref_key += 1
      @model.put_cell(cell_values)
    end

    def update(values)
      values.each do |key, value|
        self[key] = value
      end

      save
    end

    def ref_key
      load
      @ref_key
    end

    def created_at
      load
      @created_at
    end

    def body
      load
      @body
    end

    def previous
      if ref_key && previous_cell_values = @model.fetch_cell(@name, ref_key - 1)
        previous_cell_values[:body] = deserialize_body(previous_cell_values[:body])
        self.class.new(@model, @name, previous_cell_values)
      end
    end

    def reload
      @body = @ref_key = @created_at = nil
    end

    def fetch(key, default)
      body.key?(key.to_s) ? self[key] : default
    end

    def present?
      load
      !@ref_key.nil?
    end

    private

    def stringify_keys(body)
      Hash[body.map {|k, v| [k.to_s, v] }] if body
    end

    def cell_values
      {
        uuid: @model.uuid,
        column_name: @name,
        ref_key: ref_key,
        created_at: created_at,
        body: serialized_body
      }
    end

    def serialized_body
      MessagePack.pack(body)
    end

    def deserialize_body(body)
      MessagePack.unpack(body)
    end

    private

    def load
      if @body.nil?
        values = @model.fetch_cell(@name)
        @body = values ? deserialize_body(values[:body]) : {}
        initialize_from_values(values)
      end
    end

    def initialize_from_values(values)
      if values
        @ref_key = values[:ref_key]
        @created_at = values[:created_at]
      end
    end
  end
end
