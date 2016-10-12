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
      @body = body
    end

    def [](key)
      body[key.to_s]
    end

    def []=(key, value)
      body[key.to_s] = value
    end

    def save
      @created_at = Time.now
      @ref_key ||= 0
      @ref_key += 1
      @model.put_cell(cell_values)
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
