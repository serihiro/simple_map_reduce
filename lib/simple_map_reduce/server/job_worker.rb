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
      
      # TODO
      post '/map_tasks' do
        # receive job
        # create job
        # enqueue job
      end

      private

      def logger
        self.class.logger ||= Logger.new(STDOUT)
      end
      
      class << self
        attr_accessor :config
        
        def setup_worker
          register_to_job_tracker
        end
        
        # TODO
        def register_to_job_tracker
          # post job_tracker /worker
        end

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
