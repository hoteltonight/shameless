RSpec.configure do |c|
  c.include(Module.new do
    def build_store(&block)
      store = Shameless::Store.new(:store) do |c|
        c.partition_urls = ['sqlite:/']
        c.shards_count = 4
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
