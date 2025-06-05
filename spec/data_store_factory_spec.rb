# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleMapReduce::DataStoreFactory do
  describe '.create' do
    context "with 'default'" do
      it 'returns DefaultDataStore instance' do
        store = described_class.create('default')
        expect(store).to be_a(SimpleMapReduce::DataStores::DefaultDataStore)
      end
    end

    context "with 'remote'" do
      let(:options) do
        {
          resource_name: 'jobs',
          resource_id: '1',
          server_url: 'http://example.com'
        }
      end

      it 'returns RemoteDataStore instance' do
        store = described_class.create('remote', options)
        expect(store).to be_a(SimpleMapReduce::DataStores::RemoteDataStore)
      end

      it 'passes options to RemoteDataStore' do
        expect(SimpleMapReduce::DataStores::RemoteDataStore).to receive(:new).with(options)
        described_class.create('remote', options)
      end
    end

    context 'with unsupported type' do
      it 'raises ArgumentError' do
        expect { described_class.create('foo') }.to raise_error(ArgumentError)
      end
    end
  end
end
