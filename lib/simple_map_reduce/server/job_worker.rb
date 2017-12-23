require 'json'
require 'sinatra'
require 'sinatra/json'
require 'sinatra/reloader' if development?

module SimpleMapReduce
  module Server
    class JobWorker < Sinatra::Base
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
          register_myself_to_job_tracker
        end

        def register_myself_to_job_tracker
          response = http_client.post do |request|
            request.url('/workers')
            request.body = { url: SimpleMapReduce.job_worker_url }.to_json
          end
          
          if response.status != 200
            raise 'failed to setup worker'
          end

          body = JSON.parse(response.body, symbolize_names: true)
          self.worker_id = body[:id]
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
      end
    end
  end
end
