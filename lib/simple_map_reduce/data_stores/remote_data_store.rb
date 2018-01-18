# frozen_string_literal: true

module SimpleMapReduce
  module DataStores
    class RemoteDataStore
      def initialize(options)
        @resource_name = options[:resource_name]
        @resource_id = options[:resource_id]
        @job_tracker_url = options[:job_tracker_url]
      end

      def save_state(event)
        http_client.put do |request|
          request.url("/#{@resource_name}/#{@resource_id}")
          request.body = { event: event }.to_json
        end
      end

      private

      HTTP_JSON_HEADER = {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      }.freeze

      def http_client
        @http_client ||= ::Faraday.new(
          url: @job_tracker_url,
          headers: HTTP_JSON_HEADER,
          request: {
            open_timeout: 10,
            timeout: 15
          }
        ) do |faraday|
          faraday.response :logger
          faraday.response :raise_error
          faraday.adapter  Faraday.default_adapter
        end
      end
    end
  end
end
