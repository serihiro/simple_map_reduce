# frozen_string_literal: true

module SimpleMapReduce
  class DataStoreFactory
    TYPES = %w(default remote).freeze

    class << self
      def create(data_store_type, options = {})
        unless TYPES.include?(data_store_type)
          raise ArgumentError, "Unsupported data_store_type: `#{data_store_type}`"
        end

        case data_store_type
        when 'default'
          SimpleMapReduce::DataStores::DefaultDataStore.new(options)
        when 'remote'
          options[:job_tracker_url] = SimpleMapReduce.job_tracker_url
          SimpleMapReduce::DataStores::RemoteDataStore.new(options)
        end
      end
    end
  end
end
