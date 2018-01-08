# frozen_string_literal: true

module SimpleMapReduce
  module Worker
    class RunReduceTaskWorker
      def perform(task, reduce_worker_id)
        task_wrapper_class_name = "TaskWrapper#{task.id.delete('-')}"
        self.class.class_eval("class #{task_wrapper_class_name}; end", 'Task Wrapper Class')
        task_wrapper_class = self.class.const_get(task_wrapper_class_name)
        task_wrapper_class.class_eval(task.task_script, 'Reduce task script')
        reduce_task = task_wrapper_class.const_get(task.task_class_name, false).new
        unless reduce_task.respond_to?(:reduce)
          # TODO: notifying to job_tracker that this task have failed
          logger.error('no reduce method')
          return
        end

        logger.info('reduce task start')

        local_input_cache = Tempfile.new
        s3_client.get_object(
          response_target: local_input_cache.path,
          bucket: task.task_input_bucket_name,
          key: task.task_input_file_path
        )
        local_input_cache.rewind

        local_output_cache = Tempfile.new
        reduce_task.reduce(local_input_cache, local_output_cache)

        local_output_cache.rewind
        s3_client.put_object(
          body: local_output_cache.read,
          bucket: task.task_output_bucket_name,
          key: "#{task.task_output_directory_path}/#{task.job_id}/#{task.id}_reduce_task_output.txt"
        )

        s3_client.delete_object(
          bucket: task.task_input_bucket_name,
          key: task.task_input_file_path
        )

        # TODO: Notify the task succeeded
      rescue => e
        logger.error(e.inspect)
        logger.error(e.backtrace.take(50))

        # TODO: Notify the task failed
      ensure
        local_input_cache&.delete
        local_output_cache&.delete
        if self.class.const_defined?(task_wrapper_class_name.to_sym)
          self.class.send(:remove_const, task_wrapper_class_name.to_sym)
        end

        begin
          response = http_client(SimpleMapReduce.job_tracker_url).put do |request|
            request.url("/workers/#{reduce_worker_id}")
            request.body = { event: 'ready' }.to_json
          end
          logger.debug(response.body)
        rescue => notify_error
          logger.fatal(notify_error.inspect)
          logger.fatal(notify_error.backtrace.take(50))
        end

        logger.info('reduce task end')
      end

      private

      def s3_client
        SimpleMapReduce::S3Client.instance.client
      end

      def logger
        SimpleMapReduce.logger
      end

      HTTP_MSGPACK_HEADER = {
        'Accept' => 'application/x-msgpack',
        'Content-Type' => 'application/x-msgpack'
      }.freeze

      def http_client(url)
        ::Faraday.new(
          url: url,
          headers: HTTP_MSGPACK_HEADER
        ) do |faraday|
          faraday.response :logger
          faraday.response :raise_error
          faraday.adapter  Faraday.default_adapter
        end
      end
    end
  end
end
