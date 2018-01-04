require 'json'
require 'sinatra'
require 'sinatra/json'
require 'sinatra/reloader' if development?

module SimpleMapReduce
  module Server
    class JobTracker < Sinatra::Base
      configure do
        use Rack::Lock
        # TODO: be configurable
        MAX_WORKER_RESERVABLE_SIZE = 5
      end
      configure :development do
        register Sinatra::Reloader
      end
      
      post '/jobs' do
        params = JSON.parse(request.body.read, symbolize_names: true)
        map_worker = self.class.fetch_available_workers
        if map_worker.empty?
          status 409
          json({succeeded: false, error_message: 'No worker is available now. Try it again.'})
          return
        end

        registered_job = nil
        begin
          registered_job = self.class.register_job(
                             map_script: params[:map_script],
                             map_class_name: params[:map_class_name],
                             reduce_script: params[:reduce_script],
                             reduce_class_name: params[:reduce_class_name],
                             job_input_bucket_name: params[:job_input_bucket_name],
                             job_input_directory_path: params[:job_input_directory_path],
                             job_output_bucket_name: params[:job_output_bucket_name],
                             job_output_directory_path: params[:job_output_directory_path],
                             map_worker: map_worker.last
                          )
        rescue => e
          self.class.store_worker(map_worker)
          status 500
          json({ succeeded: false, error_message: e.message })
          return
        end

        json({ succeeded: true, id: registered_job.id })
      end
      
      get '/jobs/:id' do
        job = self.class.jobs&.[](params[:id].to_i)
        if job.nil?
          status 404
          json({ succeeded: false, error_message: 'job not found' })
        else
          json({ job: job.to_h})
        end
      end
      
      get '/jobs' do
        json(self.class.jobs&.values&.map(&:to_h) || [])
      end

      get '/workers/:id' do
        worker = self.class.workers[params[:id]]
        if worker.nil?
          status 404
          json({ succeeded: false, job: nil })
        else
          json({ succeeded: true, job: worker.to_h })
        end
      end
      
      post '/workers' do
        params = JSON.parse(request.body.read, symbolize_names: true)
        job = self.class.register_worker(url: params[:url])
        json({ succeeded: true, id: job.id })
      end
      
      put '/workers/:id' do
        worker = self.class.workers[params[:id]]
        if worker.nil?
          status 404
          json({ succeeded: false, job: nil })
        else
          params = JSON.parse(request.body.read, symbolize_names: true)
          worker.update!(params)
          json({ succeeded: true, job: worker.to_h })
        end
      end
      
      get '/workers' do
        json(self.class.workers&.values&.map(&:to_h) || [])
      end
      
      post '/workers/reserve' do
        params = JSON.parse(request.body.read, symbolize_names: true) rescue {}
        worker_size = [
                         (params[:worker_size].to_i.zero? ? 1 : params[:worker_size].to_i.abs),
                         MAX_WORKER_RESERVABLE_SIZE
                       ].min
        begin
          reserved_workers = self.class.fetch_available_workers(worker_size)
          json({ succeeded: true, reserved_workers: reserved_workers.map(&:to_h) })
        rescue => e
          reserved_workers.each { |reserved_worker| self.class.store_worker(reserved_worker) }
          status 500
          json({ succeeded: false, error_message: e.message })
        end
      end
      
      class << self
        attr_accessor :config
        attr_accessor :logger
        attr_reader :jobs
        attr_reader :job_manager
        attr_reader :workers
        
        def setup_job_tracker
          check_s3_access
          create_s3_buckets_if_not_existing
          logger.info('All setup process is done successfully. The job tracker is operation ready.')
        end
        
        def check_s3_access
          s3_client.list_buckets
          logger.info('[OK] s3 connection test')
        end
        
        def create_s3_buckets_if_not_existing
          current_bucket_names = s3_client.list_buckets.buckets.map(&:name)
          unless current_bucket_names.include?(SimpleMapReduce.s3_input_bucket_name)
            s3_client.create_bucket(bucket: SimpleMapReduce.s3_input_bucket_name)
            logger.info("create bucket #{SimpleMapReduce.s3_input_bucket_name}")
          end
  
          unless current_bucket_names.include?(SimpleMapReduce.s3_intermediate_bucket_name)
            s3_client.create_bucket(bucket: SimpleMapReduce.s3_intermediate_bucket_name)
            logger.info("create bucket #{SimpleMapReduce.s3_intermediate_bucket_name}")
          end
  
          unless current_bucket_names.include?(SimpleMapReduce.s3_output_bucket_name)
            s3_client.create_bucket(bucket: SimpleMapReduce.s3_output_bucket_name)
            logger.info("create bucket #{SimpleMapReduce.s3_output_bucket_name}")
          end
          logger.info('[OK] confirmed that all necessary s3 buckets exist')
        end

        def register_job(map_script:,
                         map_class_name:,
                         reduce_script:,
                         reduce_class_name:,
                         job_input_bucket_name:,
                         job_input_directory_path:,
                         job_output_bucket_name:,
                         job_output_directory_path:,
                         map_worker:)
  
          job = ::SimpleMapReduce::Server::Job.new(
                  map_script: map_script,
                  map_class_name: map_class_name,
                  reduce_script: reduce_script,
                  reduce_class_name: reduce_class_name,
                  job_input_directory_path: job_input_directory_path,
                  job_input_bucket_name: job_input_bucket_name,
                  job_output_bucket_name: job_output_bucket_name,
                  job_output_directory_path: job_output_directory_path,
                  map_worker: map_worker
                )
          if @jobs.nil?
            @jobs = {}
          end
          
          # enqueue job
          job_manager.enqueue_job!(SimpleMapReduce::Worker::RegisterMapTaskWorker, args: job)
          
          @jobs[job.id] = job
          job
        end
        
        def register_worker(url:)
          worker = ::SimpleMapReduce::Server::Worker.new(url: url)
          if @workers.nil?
            @workers = {}
          end
          
          @workers[worker.id] = worker
          worker
        end
        
        def fetch_available_workers(worker_size = 1)
          mutex.lock
          
          if @workers.nil? || @workers.empty?
            return []
          end
          
          ready_workers = @workers.select { |_id, worker| worker.ready? }
          if ready_workers.count > 0
            ready_workers = ready_workers.keys.take(worker_size)

            ready_workers.map do |retry_worker_id|
              @workers[retry_worker_id].reserve
              @workers[retry_worker_id]
            end
          else
            return []
          end
        ensure
          mutex.unlock
        end
        
        def store_worker(worker)
          mutex.lock
          if @workers.nil?
            @workers = {}
          end
          
          @workers[worker.id].ready!
        ensure
          mutex.unlock
        end
  
        def job_manager
          @job_manager ||= ::Rasteira::EmbedWorker::Manager.run
        end
        
        def mutex
          @mutex ||= Mutex.new
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
