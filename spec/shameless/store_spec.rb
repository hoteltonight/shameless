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
end
