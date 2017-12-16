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
        self.class.job_manager.enqueue_job!(SimpleMapReduce::Worker::RunMapTaskWorker, args: job)

        json({ succeeded: true, job_id: job.id })
      end
      
      post '/reduce_tasks' do
        raw_body = request.body.read
        task = SimpleMapReduce::Server::Task.deserialize(raw_body)
        
        self.class.job_manager.enqueue_job!(SimpleMapReduce::Worker::RunReduceTaskWorker, args: task)
  
        json({ succeeded: true, job_id: task.job_id, task_id: task.id})
      end

      class << self
        attr_accessor :config
        
        def job_manager
          @job_manager ||= ::Rasteira::EmbedWorker::Manager.run
        end
        
        def http_client
          @http_client ||= ::Faraday.new(
          url: @config['job_tracker_url'],
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
end
