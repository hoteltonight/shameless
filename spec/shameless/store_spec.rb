describe Shameless::Store do
  it 'works' do
    store, model = build_store
    instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s)

    expect(instance.uuid).not_to be_nil
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

  it 'properly loads base values when using where' do
    store, model = build_store
    instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s, net_rate: 90)

    fetched = model.where(hotel_id: 1).first
    expect(fetched.uuid).to eq(instance.uuid)
    expect(fetched.ref_key).to eq(1)
  end

  it 'names the model by downcasing the class name' do
    store, model = build_store do |store|
      Store = store

      class MyModel
        Store.attach(self)

        index do
          integer :my_id
          shard_on :my_id
        end
      end
    end

    partition = store.send(:partitions).first
    expect(partition.from('store_mymodel_000001').count).to eq(0)

    Object.send(:remove_const, :MyModel)
    Object.send(:remove_const, :Store)
  end

  it 'names the default index "primary"' do
    store, model = build_store do |store|
      Store = store

      class MyModel
        Store.attach(self)

        index do
          integer :my_id
          shard_on :my_id
        end
      end
    end

    partition = store.send(:partitions).first
    expect(partition.from('store_mymodel_primary_000001').count).to eq(0)

    Object.send(:remove_const, :MyModel)
    Object.send(:remove_const, :Store)
  end

  it 'allows naming the index' do
    store, model = build_store do |store|
      Store = store

      class MyModel
        Store.attach(self)

        index :foo do
          integer :my_id
          shard_on :my_id
        end
      end
    end

    partition = store.send(:partitions).first
    expect(partition.from('store_mymodel_foo_000001').count).to eq(0)

    Object.send(:remove_const, :MyModel)
    Object.send(:remove_const, :Store)
  end
end
