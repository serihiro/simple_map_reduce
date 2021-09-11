# frozen_string_literal: true

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
        self.class.worker.work!
        job.start!
        self.class.job_manager.enqueue_job!(SimpleMapReduce::Worker::RunMapTaskWorker, args: [job, self.class.worker])

        json(succeeded: true, job_id: job.id)
      end

      post '/reduce_tasks' do
        raw_body = request.body.read
        task = SimpleMapReduce::Server::Task.deserialize(raw_body)
        self.class.worker.work!
        self.class.job_manager.enqueue_job!(SimpleMapReduce::Worker::RunReduceTaskWorker, args: [task, self.class.worker])

        json(succeeded: true, job_id: task.job_id, task_id: task.id)
      end

      put '/workers/:id' do
        body = JSON.parse(request.body.read, symbolize_names: true)
        if params[:id] != self.class.worker_id
          status 404
          json(succeeded: false, error_message: 'The specified worker id was not found.')
          return
        end

        begin
          self.class.worker.update!(body)
          json(succeeded: true, worker: self.class.worker.dump)
        rescue => e
          puts e.inspect
          status 400
          json(succeeded: false, error_class: e.class.to_s, error_message: e.message)
        end
      end

      get '/workers/:id' do
        if params[:id] != self.class.worker_id
          status 404
          json(succeeded: false, error_message: 'The specified worker id was not found.')
        else
          json(succeeded: true, worker: self.class.worker.dump)
        end
      end

      class << self
        attr_reader :worker_id
        attr_reader :worker

        def setup_worker
          check_s3_access
          register_myself_to_job_tracker
          job_manager
          logger.info('All setup process is done successfully. This worker is operation ready.')
          logger.info("This job worker url: #{SimpleMapReduce.job_worker_url}, id: #{worker_id}")
          logger.info("This job worker status url: #{SimpleMapReduce.job_worker_url}/workers/#{worker_id}")
          logger.info("The job tracker url: #{SimpleMapReduce.job_tracker_url}")
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
          @worker_id = body[:id]
          @worker = SimpleMapReduce::Server::Worker.new(
            id: @worker_id,
            url: SimpleMapReduce.job_worker_url
          )
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

        # @override `Sinatra::Base#quit!`
        # https://github.com/sinatra/sinatra/blob/2e980f3534b680fbd79d7ec39552b4afb7675d6c/lib/sinatra/base.rb#L1483-L1491
        def quit!
          job_manager&.shutdown_workers!
          super
        end
      end
    end
  end
end
