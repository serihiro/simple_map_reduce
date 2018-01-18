# frozen_string_literal: true

module SimpleMapReduce
  module Worker
    class RunMapTaskWorker
      class InvalidMapTaskError < StandardError; end

      def perform(job, map_worker_id)
        task_wrapper_class_name = "TaskWrapper#{job.id.delete('-')}"
        self.class.class_eval("class #{task_wrapper_class_name}; end", 'Task Wrapper Class')
        task_wrapper_class = self.class.const_get(task_wrapper_class_name)
        task_wrapper_class.class_eval(job.map_script, 'Map task script')
        map_task = task_wrapper_class.const_get(job.map_class_name, false).new
        unless map_task.respond_to?(:map)
          raise InvalidMapTaskError, 'no map method'
        end
        logger.info('map task start')

        local_input_cache = Tempfile.new
        s3_client.get_object(
          response_target: local_input_cache.path,
          bucket: job.job_input_bucket_name,
          key: job.job_input_directory_path
        )
        local_input_cache.rewind

        local_output_cache = Tempfile.new
        local_input_cache.each_line(chomp: true, rs: "\n") do |line|
          map_task.map(line, local_output_cache)
        end

        local_output_cache.rewind
        logger.debug("output data size: #{local_output_cache.size}")
        logger.debug('---map output digest---')
        local_output_cache.take(5).each do |line|
          logger.debug(line)
        end
        logger.debug('---map output digest---')

        response = http_client(SimpleMapReduce.job_tracker_url).post do |request|
          request.url('/workers/reserve')
          # TODO: providing a way to specify worker_size
          request.body = { worker_size: 2 }.to_json
        end
        logger.debug(response.body)

        # {"succeeded":true,"workers":[{"id":70157882164440,"url":"http://localhost:4569","state":'reserved'}]}
        reserved_workers = JSON.parse(response.body, symbolize_names: true)[:reserved_workers]
        if reserved_workers.count == 0
          # keep working with same worker
          reserved_workers << { id: map_worker_id, url: job.map_worker_url, state: 'working' }
        end

        shuffle(job, reserved_workers, local_output_cache)

        unless reserved_workers.map { |w| w[:id] }.include?(map_worker_id)
          response = http_client(SimpleMapReduce.job_tracker_url).put do |request|
            request.url("/workers/#{map_worker_id}")
            request.body = { event: 'ready' }.to_json
          end
          logger.debug(response.body)
        end
      rescue => e
        logger.error(e.inspect)
        logger.error(e.backtrace.take(50))
        job.failed!
        # TODO: notifying to job_tracker that this task have failed
      ensure
        local_input_cache&.delete
        local_output_cache&.delete
        reserved_workers&.each do |worker|
          worker[:shuffled_local_output]&.delete
        end
        if self.class.const_defined?(task_wrapper_class_name.to_sym)
          self.class.send(:remove_const, task_wrapper_class_name.to_sym)
        end
        logger.info('map task end')
      end

      private

      def s3_client
        SimpleMapReduce::S3Client.instance.client
      end

      def logger
        SimpleMapReduce.logger
      end

      HTTP_JSON_HEADER = {
        'Accept' => 'application/x-msgpack',
        'Content-Type' => 'application/x-msgpack'
      }.freeze

      def http_client(url)
        ::Faraday.new(
          url: url,
          headers: HTTP_JSON_HEADER
        ) do |faraday|
          faraday.response :logger
          faraday.response :raise_error
          faraday.adapter  Faraday.default_adapter
        end
      end

      def shuffle(job, workers, local_output_cache)
        workers_count = workers.count
        raise 'No workers' unless workers_count > 0

        workers.each do |worker|
          worker[:shuffled_local_output] = Tempfile.new
        end

        local_output_cache.each_line(rs: "\n") do |raw_line|
          output = JSON.parse(raw_line, symbolize_names: true)
          partition_id = output[:key].hash % workers_count
          workers[partition_id][:shuffled_local_output].puts(output.to_json)
        end

        task_script = job.reduce_script
        task_class_name = job.reduce_class_name
        task_input_bucket_name = SimpleMapReduce.s3_intermediate_bucket_name
        task_output_bucket_name = job.job_output_bucket_name
        task_output_directory_path = job.job_output_directory_path
        task_input_file_path_prefix = "#{job.id}/map_output_#{Time.now.to_i}/"

        workers.each_with_index do |worker, partition_id|
          reduce_task = ::SimpleMapReduce::Server::Task.new(
            job_id: job.id,
            task_class_name: task_class_name,
            task_script: task_script,
            task_input_bucket_name: task_input_bucket_name,
            task_input_file_path: "#{task_input_file_path_prefix}#{partition_id}_map_output.txt",
            task_output_bucket_name: task_output_bucket_name,
            task_output_directory_path: task_output_directory_path
          )

          local_output_cache = worker[:shuffled_local_output]
          local_output_cache.rewind
          s3_client.put_object(
            body: local_output_cache.read,
            bucket: reduce_task.task_input_bucket_name,
            key: reduce_task.task_input_file_path
          )

          response = http_client(worker[:url]).post do |request|
            request.url('/reduce_tasks')
            request.body = reduce_task.serialize
          end
          logger.debug(response.body)

          next if worker[:state] == 'working'
          response = http_client(SimpleMapReduce.job_tracker_url).put do |request|
            request.url("/workers/#{worker[:id]}")
            request.body = { event: 'work' }.to_json
          end
          logger.debug(response.body)
        end
      end
    end
  end
end
