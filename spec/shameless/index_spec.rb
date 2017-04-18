describe Shameless::Index do
  before(:context) do
    build_store do |store|
      Store = store

      class MyModel
        Store.attach(self)

        index do
          integer :primary_id
          shard_on :primary_id
        end

        index :foo do
          integer :my_id
          string :check_in_date
          shard_on :my_id
        end
      end
    end
  end

  after(:context) do
    Object.send(:remove_const, :MyModel)
    Object.send(:remove_const, :Store)
  end

  let(:today) { Date.today.to_s }
  let(:tomorrow) { (Date.today + 1).to_s }

  it 'allows querying by a named index' do
    MyModel.put(primary_id: 1, my_id: 1, foo: 'bar', check_in_date: today)
    MyModel.put(primary_id: 2, my_id: 1, foo: 'baz', check_in_date: tomorrow)

    results = MyModel.foo_index.where(my_id: 1)

    expect(results.size).to eq(2)
    expect(results.first[:foo]).to eq('bar')
  end

  it 'allows querying with block filters' do
    MyModel.put(primary_id: 1, my_id: 1, check_in_date: today)
    MyModel.put(primary_id: 2, my_id: 1, check_in_date: tomorrow)

    results = MyModel.foo_index.where(my_id: 1) { |o| o.check_in_date > today }

    expect(results.size).to eq(1)
    expect(results.first[:check_in_date]).to eq(tomorrow)
  end
end
