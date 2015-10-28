require 'spec_helper'

describe DummyThermo do
  it 'has a version number' do
    expect(DummyThermo::VERSION).not_to be nil
  end

  describe DummyThermo::Sensor do
    context 'new without args' do
      it 'is set every months conf' do
        ds = DummyThermo::Sensor.new
        (1 .. 12).each do |i|
          expect(ds.conf[i]).to include(:max, :min, :maxhour, :minhour)
        end
      end

      it 'generate spot dummy data' do
        ds = DummyThermo::Sensor.new
        expect(ds.gen).to be_within(5).of(20)
      end

      it 'generate dummy data of compared recently data' do
        ds = DummyThermo::Sensor.new
        t = Time.new(2015,10,25,12)
        expect(ds.gen(t, t - 10, 20)).to be_within(2.8).of(20)
      end
    end
    # the following test needs "outdoor" configuration in config/dummy_thermo.yml
    context 'new with the arg' do
      it 'is set every months conf' do
        ds = DummyThermo::Sensor.new("outdoor")
        (1 .. 12).each do |i|
          expect(ds.conf[i]).to include(:max, :min, :maxhour, :minhour)
        end
      end

      it 'raises error when the arg is not defined' do
        expect{ DummyThermo::Sensor.new("not defined") }.to raise_error
      end

      it 'generate spot dummy data' do
        ds = DummyThermo::Sensor.new
        expect(ds.gen).to be_within(5).of(20)
      end

      it 'generate dummy data of compared recently data' do
        ds = DummyThermo::Sensor.new
        t = Time.new(2015,10,25,12)
        expect(ds.gen(t, t - 10, 20)).to be_within(2.8).of(20)
      end
    end
  end
end
