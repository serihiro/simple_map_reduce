# frozen_string_literal: true

require 'securerandom'
require 'forwardable'
require 'aasm'

module SimpleMapReduce
  module Server
    class Worker
      extend Forwardable
      include AASM

      attr_accessor :url

      delegate current_state: :aasm
      alias state current_state

      STATES = %i(ready reserved working).freeze

      aasm do
        after_all_transitions :save_state

        state :ready, initial: true
        state :reserved
        state :working

        event :ready do
          transitions to: :ready
        end

        event :reserve do
          transitions from: %i(ready working), to: :reserved
        end

        event :work do
          transitions from: %i(reserved working), to: :working
        end
      end

      def initialize(url:, id: nil, state: nil, data_store_type: 'default')
        @url = url
        @id = id
        if STATES.include?(state)
          aasm_write_state_without_persistence(state)
        end
        @data_store = SimpleMapReduce::DataStoreFactory.create(data_store_type,
                                                             resource_name: 'workers', resource_id: self.id)
        unless valid?
          raise ArgumentError, 'invalid url'
        end
      end

      def id
        @id ||= SecureRandom.uuid
      end

      def dump
        {
          id: id,
          url: @url,
          state: state
        }
      end

      # update Job
      # @params [Hash] attributes
      # @options attributes [String] url
      # @options attributes [String] event
      def update!(url: nil, event: nil)
        if url
          self.url = url
        end

        if event
          public_send(event.to_sym)
        end
      end

      private

      def valid?
        !@url.to_s.empty? && @url =~ URI::DEFAULT_PARSER.make_regexp
      end

      def save_state
        @data_store.save_state(aasm.current_event)
      end
    end
  end
end
