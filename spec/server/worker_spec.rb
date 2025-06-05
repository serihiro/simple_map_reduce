# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleMapReduce::Server::Worker do
  let(:worker) { build(:worker) }

  describe '#update!' do
    context 'when called with an event symbol' do
      it 'updates the state accordingly' do
        expect(worker.state).to eq(:ready)
        worker.update!(:reserve)
        expect(worker.state).to eq(:reserved)
      end
    end

    context 'when called with a hash of attributes' do
      it 'updates the state based on the :event key' do
        worker.update!(event: :reserve)
        worker.update!(event: :work)
        expect(worker.state).to eq(:working)
      end
    end
  end
end
