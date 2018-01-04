# frozen_string_literal: true

module SimpleMapReduce
  module Worker
    class RegisterMapTaskWorker
      def perform(job)
        logger.info('register map task worker start!')
        client = http_client(job.map_worker.url)
        response = client.post do |request|
          request.url('/map_tasks')
          request.body = job.serialize
        end
        logger.debug(response.body)

        job.map_worker.work!
        job.start!
      rescue => e
        logger.error(e.inspect)
        logger.error(e.backtrace.take(50))
        SimpleMapReduce::Server::JobTracker.store_worker(job.map_worker)
        job.failed!
      end

      private

      HTTP_MSGPACK_HEADER = {
        'Accept' => 'application/x-msgpack',
        'Content-Type' => 'application/x-msgpack'
      }.freeze

      def http_client(url)
        ::Faraday.new(
          url: url,
          headers: HTTP_MSGPACK_HEADER,
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

      def logger
        SimpleMapReduce.logger
      end
    end
  end
end
