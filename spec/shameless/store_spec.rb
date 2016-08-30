describe Shameless::Store do
  def build_store
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

    [store, model]
  end

  it 'works' do
    store, model = build_store
    instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s)

    expect(model.where(hotel_id: 1).first.uuid).to eq(instance.uuid)
  end

  it 'allows access to base fields' do
    store, model = build_store
    instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s)
    fetched = model.where(hotel_id: 1).first

    expect(fetched[:hotel_id]).to eq(1)
    expect(fetched[:room_type]).to eq('roh')
    expect(fetched[:check_in_date]).to eq(Date.today.to_s)
  end

  it 'stores non-index fields on the body' do
    store, model = build_store
    instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s, net_rate: 90)
    fetched = model.where(hotel_id: 1).first

    expect(fetched[:net_rate]).to eq(90)
  end
end
