module SimpleMapReduce
  module Worker
    class RunReduceTaskWorker
      def perform(task, reduce_worker_id)
        task_wrapper_class_name = "TaskWrapper#{task.id.gsub('-', '')}"
        self.class.class_eval ("class #{task_wrapper_class_name}; end")
        task_wrapper_class = self.class.const_get(task_wrapper_class_name)
        task_wrapper_class.class_eval(task.task_script)
        reduce_task = task_wrapper_class.const_get(task.task_class_name, false).new
        unless reduce_task.respond_to?(:reduce)
          # TODO: notify job_tracker
          puts 'no reduce method'
          return
        end

        puts 'reduce task start'

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

        response = http_client(SimpleMapReduce.job_tracker_url).put do |request|
          request.url("/workers/#{reduce_worker_id}")
          request.body = { event: 'ready' }.to_json
        end
      rescue => e
        puts e.inspect
        puts e.backtrace.take(10)
          # TODO: fail処理
      ensure
        local_input_cache&.delete
        local_output_cache&.delete
        self.class.send(:remove_const, task_wrapper_class_name.to_sym)
        puts 'reduce task end'
      end

      private

      def s3_client
        SimpleMapReduce::S3Client.instance.client
      end

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
