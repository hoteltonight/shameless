RSpec.configure do |c|
  c.include(Module.new do
    def build_store(name: :store, partitions_count: 1, connection_options: nil, database_extensions: nil, &block)
      store = Shameless::Store.new(name) do |c|
        c.partition_urls = Array.new(partitions_count) { 'sqlite:/' }
        c.shards_count = 4
        c.connection_options = connection_options
        c.database_extensions = database_extensions
      end

      model = Class.new do
        store.attach(self, :rates)

        index do
          integer :hotel_id
          string :room_type
          string :check_in_date

          shard_on :hotel_id
        end
      end

      block.call(store) if block

      store.create_tables!

      [store, model]
    end
  end)
end
