require 'msgpack'

module Shameless
  class Cell
    BASE = 'base'

    def self.base(model, body)
      new(model, BASE, body)
    end

    def initialize(model, name, body = nil)
      @model = model
      @name = name
      @body = stringify_keys(body)
    end

    def [](key)
      body[key.to_s]
    end

    def []=(key, value)
      @model.prevent_readonly_attribute_mutation!(key)
      body[key.to_s] = value
    end

    def save
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
      fetch
      @ref_key
    end

    def created_at
      fetch
      @created_at
    end

    def body
      fetch
      @body
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

    def fetch
      if @body.nil?
        values = @model.fetch_cell(@name)
        @ref_key = values[:ref_key] if values
        @created_at = values[:created_at] if values
        @body = values ? deserialize_body(values[:body]) : {}
      end
    end
  end
end
