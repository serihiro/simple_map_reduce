# frozen_string_literal: true

module SimpleMapReduce
  module Worker
    class PollingWorkersStatusWorker
      def perform(workers)
        logger.debug("begin polling workers: #{workers.keys}")
        workers.each do |id, worker|
          begin
            response = http_client(worker.url).get("/workers/#{worker.id}")
            body = JSON.parse(response.body, symbolize_names: true)[:worker]
            worker.aasm.current_state = body[:state].to_sym
          rescue => e
            logger.error(e.inspect)
            logger.error(e&.response&.inspect)
            logger.info("Worker #{worker.id} is removed from workers")
            workers.delete(id)
          end
        end
        logger.debug("finish polling workers: #{workers.keys}")
      end

      private

      HTTP_JSON_HEADER = {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      }.freeze

      def http_client(url)
        ::Faraday.new(
          url: url,
          headers: HTTP_JSON_HEADER,
          request: {
            open_timeout: 5,
            timeout: 10
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
