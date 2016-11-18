describe Shameless::Cell do
  it 'allows storing arbitrary content in cells' do
    model = build_model_with_cell
    instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s)

    instance.meta[:foo] = 'bar'
    instance.meta.save

    expect(instance.meta[:foo]).to eq('bar')

    fetched = model.where(hotel_id: 1).first

    expect(fetched.meta[:foo]).to eq('bar')
  end

  it 'increments ref_key on save' do
    model = build_model_with_cell
    instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s)

    expect(instance.meta.ref_key).to eq(nil)

    instance.meta[:foo] = 'bar'
    instance.meta.save

    expect(instance.meta.ref_key).to eq(0)

    instance.meta.save

    expect(instance.meta.ref_key).to eq(1)

    fetched = model.where(hotel_id: 1).first

    expect(fetched.meta.ref_key).to eq(1)
  end

  it 'touches created_at on save' do
    model = build_model_with_cell
    instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s)

    expect(instance.meta.created_at).to eq(nil)

    instance.meta[:foo] = 'bar'
    instance.meta.save

    initial_created_at = instance.meta.created_at
    expect(instance.meta.created_at).not_to be_nil

    sleep(0.1)

    instance.meta.save

    last_created_at = instance.meta.created_at
    expect(last_created_at).to be > initial_created_at

    fetched = model.where(hotel_id: 1).first

    expect(fetched.meta.created_at).to eq(last_created_at)
  end

  it 'allows to call save without changing anything' do
    model = build_model_with_cell
    instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s)

    instance.meta.save
    expect(instance.meta.ref_key).to eq(0)

    instance = model.where(hotel_id: 1).first

    instance.meta.save
    expect(instance.meta.ref_key).to eq(1)
  end

  describe '#update' do
    it 'assigns all values from argument' do
      model = build_model_with_cell
      instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s)

      instance.meta.update(net_rate: 100)
      expect(instance.meta[:net_rate]).to eq(100)
      expect(instance.meta.ref_key).to eq(0)

      instance.meta.update(gross_rate: 160)
      expect(instance.meta[:net_rate]).to eq(100)
      expect(instance.meta[:gross_rate]).to eq(160)
      expect(instance.meta.ref_key).to eq(1)
    end
  end

  describe '#previous' do
    it 'returns nil for initial version' do
      model = build_model_with_cell
      instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s)

      expect(instance.meta.previous).to be_nil
    end

    it 'returns nil for initial version after save' do
      model = build_model_with_cell
      instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s)
      instance.meta[:net_rate] = 90
      instance.meta.save

      expect(instance.meta.previous).to be_nil
    end

    it 'returns the previous version of the cell' do
      model = build_model_with_cell
      instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s)
      instance.meta[:net_rate] = 90
      instance.meta.save

      instance.meta[:net_rate] = 100
      instance.meta.save

      previous = instance.meta.previous
      expect(instance.meta.ref_key).to eq(1)
      expect(previous.ref_key).to eq(0)
      expect(previous[:net_rate]).to eq(90)
    end
  end

  describe '#reload' do
    it 'lazily reloads cell state' do
      model = build_model_with_cell
      instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s)
      instance.meta.update(net_rate: 90)

      second_instance = model.where(hotel_id: 1).first
      second_instance.meta.update(net_rate: 100)

      instance.meta.reload
      expect(instance.meta.ref_key).to eq(1)
      expect(instance.meta[:net_rate]).to eq(100)
    end
  end

  describe '#fetch' do
    it 'returns default when value is missing' do
      model = build_model_with_cell
      instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s)

      expect(instance.meta.fetch(:foo, 'bar')).to eq('bar')
    end

    it 'returns value when present' do
      model = build_model_with_cell
      instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s)
      instance.meta[:foo] = 'bar'

      expect(instance.meta.fetch(:foo, 'baz')).to eq('bar')
    end

    it 'returns false when value of false is present' do
      model = build_model_with_cell
      instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s)
      instance.meta[:foo] = false

      expect(instance.meta.fetch(:foo, 'bar')).to eq(false)
    end
  end

  describe '#present?' do
    it 'returns false if cell has not been saved yet' do
      model = build_model_with_cell
      instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s)

      expect(instance.meta).not_to be_present
    end

    it 'returns false if cell has been modified but not saved' do
      model = build_model_with_cell
      instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s)

      instance.meta[:net_rate] = 90

      expect(instance.meta).not_to be_present
    end

    it 'returns true if cell has been saved' do
      model = build_model_with_cell
      instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s)

      instance.meta.update(net_rate: 90)

      expect(instance.meta).to be_present
    end

    it 'returns true if cell has been saved and reloaded' do
      model = build_model_with_cell
      instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s)

      instance.meta.update(net_rate: 90)

      instance = model.where(hotel_id: 1).first

      expect(instance.meta).to be_present
    end
  end
end
