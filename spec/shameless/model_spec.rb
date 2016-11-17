describe Shameless::Model do
  it 'initializes created_at' do
    store, model = build_store
    now = Time.now
    instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s)

    expect(instance.created_at).to be >= now
  end

  describe '#legacy_created_at_is_bigint' do
    it 'uses bigint for created_at' do
      store, model = build_store(legacy_created_at_is_bigint: true)
      before = Time.now
      instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s)
      after = Time.now

      expect(instance.created_at).to be >= (before.to_f * 1000).to_i
      expect(instance.created_at).to be <= (after.to_f * 1000).to_i
    end
  end

  it 'unifies symbol and string keys' do
    store, model = build_store
    instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s, net_rate: 90)

    expect(instance["net_rate"]).to eq(90)

    instance[:net_rate] = 100
    expect(instance["net_rate"]).to eq(100)

    instance["net_rate"] = 110
    expect(instance[:net_rate]).to eq(110)

    expect(instance.base.body.keys.count).to eq(4)

    fetched = model.where(hotel_id: 1).first

    expect(fetched.base.body.keys.count).to eq(4)
  end

  it 'allows updates via the instance' do
    store, model = build_store
    instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s, net_rate: 90)

    instance[:net_rate] = 100
    instance.save

    fetched = model.where(hotel_id: 1).first
    expect(fetched[:net_rate]).to eq(100)
  end

  it 'prevents updates to index fields' do
    store, model = build_store
    instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s, net_rate: 90)

    message = "The attribute hotel_id cannot be modified because it's part of the primary index"
    expect { instance[:hotel_id] = 2 }.to raise_error(Shameless::ReadonlyAttributeMutation, message)
  end

  it 'prevents updates to index fields even when accessed as strings' do
    store, model = build_store
    instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s, net_rate: 90)

    message = "The attribute hotel_id cannot be modified because it's part of the primary index"
    expect { instance['hotel_id'] = 2 }.to raise_error(Shameless::ReadonlyAttributeMutation, message)
  end

  it 'puts a new revision for a second put on the same index values' do
    store, model = build_store
    instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s, net_rate: 90)
    second_instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s, net_rate: 100)

    expect(second_instance.uuid).to eq(instance.uuid)
    expect(second_instance.ref_key).to eq(2)
  end

  it 'increments ref_key on update' do
    store, model = build_store
    instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s, net_rate: 90)

    expect(instance.ref_key).to eq(1)

    instance[:net_rate] = 100
    instance.save

    expect(instance.ref_key).to eq(2)
    fetched = model.where(hotel_id: 1).first
    expect(fetched.ref_key).to eq(2)
  end

  describe '#table_name' do
    it 'concatenates store name and model name' do
      _, model = build_store

      expect(model.table_name).to eq("store_rates")
    end

    it 'does not prefix table names if store name is nil' do
      _, model = build_store(name: nil)

      expect(model.table_name).to eq("rates")
    end
  end

  describe '#update' do
    it 'assigns all values from argument' do
      store, model = build_store
      instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s, net_rate: 90)

      instance.update(net_rate: 100)

      expect(instance.ref_key).to eq(2)
      expect(instance[:net_rate]).to eq(100)
      expect(instance[:hotel_id]).to eq(1)
    end
  end

  describe '#previous' do
    it 'returns the previous version of the base cell' do
      _, model = build_store
      instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s, net_rate: 90)

      instance.update(net_rate: 100)

      previous = instance.previous
      expect(instance.ref_key).to eq(2)
      expect(previous.ref_key).to eq(1)
      expect(previous[:net_rate]).to eq(90)
    end
  end

  describe '#reload' do
    it 'lazily reloads base cell state' do
      _, model = build_store
      instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s, net_rate: 90)

      second_instance = model.where(hotel_id: 1).first
      second_instance.update(net_rate: 100)

      instance.reload
      expect(instance.ref_key).to eq(2)
      expect(instance[:net_rate]).to eq(100)
    end
  end

  describe '#fetch' do
    it 'returns value from base cell' do
      _, model = build_store
      instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s, net_rate: 90)

      expect(instance.fetch(:net_rate, 100)).to eq(90)
      expect(instance.fetch(:foo, 'bar')).to eq('bar')
    end
  end
end
