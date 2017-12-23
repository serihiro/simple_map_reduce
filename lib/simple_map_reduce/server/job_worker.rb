require 'json'
require 'sinatra'
require 'sinatra/json'
require 'sinatra/reloader' if development?

module SimpleMapReduce
  module Server
    class JobWorker < Sinatra::Base
      configure do
        use Rack::Lock
      end
      configure :development do
        register Sinatra::Reloader
      end
    
      post '/map_tasks' do
        raw_body = request.body.read
        job = SimpleMapReduce::Server::Job.deserialize(raw_body)
        self.class.job_manager.enqueue_job!(SimpleMapReduce::Worker::RunMapTaskWorker, args: [job, self.class.worker_id])

        json({ succeeded: true, job_id: job.id })
      end
      
      post '/reduce_tasks' do
        raw_body = request.body.read
        task = SimpleMapReduce::Server::Task.deserialize(raw_body)
        
        self.class.job_manager.enqueue_job!(SimpleMapReduce::Worker::RunReduceTaskWorker, args: [task, self.class.worker_id])
  
        json({ succeeded: true, job_id: task.job_id, task_id: task.id})
      end

      class << self
        attr_accessor :worker_id
      
        def setup_worker
          check_s3_access
          register_myself_to_job_tracker
          logger.info('All setup process is done successfully. This worker is operation ready.')
        end
        
        def check_s3_access
          s3_client.list_buckets
          logger.info('[OK] s3 connection test')
        end

        def register_myself_to_job_tracker
          response = http_client.post do |request|
            request.url('/workers')
            request.body = { url: SimpleMapReduce.job_worker_url }.to_json
          end
          
          body = JSON.parse(response.body, symbolize_names: true)
          self.worker_id = body[:id]
          logger.info("[OK] registering this worker to the job_tracker #{SimpleMapReduce.job_worker_url}")
        end
  
        def job_manager
          @job_manager ||= ::Rasteira::EmbedWorker::Manager.run
        end
  
        def http_client
          @http_client ||= ::Faraday.new(
              url: SimpleMapReduce.job_tracker_url,
              headers: {
                  'Accept' => 'application/json',
                  'Content-Type' => 'application/json'
              }
          ) do |faraday|
            faraday.response :raise_error
            faraday.adapter  Faraday.default_adapter
          end
        end

        def s3_client
          SimpleMapReduce::S3Client.instance.client
        end

        def logger
          SimpleMapReduce.logger
        end
      end
    end
  end
end
