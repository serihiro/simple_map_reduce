module SimpleMapReduce
  module Worker
    class RegisterMapTaskWorker
      def perform(job)
        client = http_client(job.map_worker[:url])
        response = client.post do |request|
                     request.url('/map_tasks')
                     request.params = { data: job.serialize }
                   end

        if response.status != 200
          SimpleMapReduce::Server::JobTracker.store_worker(job.map_worker)
          job.failed!
        else
          job.map_worker.working!
          job.in_process!
        end
      end

      private

      def http_client(url)
        ::Faraday.new(
          url: url,
          headers: {
                      'Accept' => 'application/json',
                      'Content-Type' => 'application/json'
                    }
        ) do |faraday|
          faraday.response :logger
          faraday.adapter  Faraday.default_adapter
        end
      end
    end
  end
end
