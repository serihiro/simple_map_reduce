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

      aasm do
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
          transitions from: :reserved, to: :working
        end
      end

      def initialize(url:)
        @url = url
        unless valid?
          raise ArgumentError, 'invalid url'
        end
      end

      def id
        @id ||= SecureRandom.uuid
      end

      def to_h
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
        !@url.to_s.empty? && @url =~ URI::regexp
      end
    end
  end
end
