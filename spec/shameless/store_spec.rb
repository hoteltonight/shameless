describe Shameless::Store do
  it 'works' do
    store = described_class.new(:store) do |c|
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

    store.create_tables!

    instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s)

    expect(model.where(hotel_id: 1).first.uuid).to eq(instance.uuid)
  end
end
