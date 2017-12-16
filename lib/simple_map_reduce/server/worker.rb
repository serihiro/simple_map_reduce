require 'securerandom'
require 'forwardable'
require 'aasm'


module SimpleMapReduce
  module Server
    class Worker
      extend Forwardable
      include AASM
      
      attr_reader :id
      attr_reader :url
      
      delegate :current_state => :aasm
      alias_method :state, :current_state
      
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
      
      def update!(attributes = {})
        attributes = attributes.slice(:url, :status)
        attributes.each_key do |key|
          next if attributes[key].nil?
          
        end
      end
    end
  end
end
