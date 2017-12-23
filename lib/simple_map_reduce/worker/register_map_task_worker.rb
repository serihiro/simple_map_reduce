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

        if response.status != 200
          SimpleMapReduce::Server::JobTracker.store_worker(job.map_worker)
          job.failed!
        else
          job.map_worker.work!
          job.start!
        end
      rescue => e
        logger.error(e.inspect)
        logger.error(e.backtrace.take(50))
      end

      private

      def http_client(url)
        ::Faraday.new(
          url: url,
          headers: {
                      'Accept' => 'application/x-msgpack',
                      'Content-Type' => 'application/x-msgpack'
                    }
        ) do |faraday|
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
