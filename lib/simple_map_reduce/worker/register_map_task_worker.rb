module SimpleMapReduce
  module Worker
    class RegisterMapTaskWorker
      def perform(job)
        puts 'register map task worker start!'
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
          job.in_process!
        end
      rescue => e
        puts e.inspect
        puts e.backtrace.take(10)
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
          faraday.response :logger
          faraday.adapter  Faraday.default_adapter
        end
      end
    end
  end
end
