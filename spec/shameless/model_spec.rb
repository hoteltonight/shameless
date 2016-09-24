describe Shameless::Model do
  it 'initializes created_at' do
    store, model = build_store
    now = Time.now
    instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s)

    expect(instance.created_at).to be >= now
  end

  it 'allows updates via the instance' do
    store, model = build_store
    instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s, net_rate: 90)

    instance[:net_rate] = 100
    instance.save

    fetched = model.where(hotel_id: 1).first
    expect(fetched[:net_rate]).to eq(100)
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
end
