module SimpleMapReduce
  module Worker
    class RunMapTaskWorker
      def perform(job)
        task_wrapper_class_name = "TaskWrapper#{job.id.gsub('-', '')}"
        self.class.class_eval ("class #{task_wrapper_class_name}; end")
        task_wrapper_class = self.class.const_get(task_wrapper_class_name)
        task_wrapper_class.class_eval(job.map_script)
        map_task = task_wrapper_class.const_get(job.map_class_name, false).new
        unless map_task.respond_to?(:map)
          # TODO: notify job_tracker
          return
        end
        puts 'map task start'
        
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
        puts "output data size: #{local_output_cache.size}"
        puts '---map output digest---'
        local_output_cache.take(5).each do |line|
          puts line
        end
        puts '---map output digest---'
        
        # job_trackerにreduceを実行するworkerのリストをもらうよ
        client = http_client(SimpleMapReduce.job_tracker_url)
        response = client.post do |request|
          request.url('/workers/reserve')
          # TODO: どうやってreduce workerの数を決めるか
          request.body = { worker_size: 1 }.to_json
        end
        
        # {"succeeded":true,"reserved_workers":[{"id":70157882164440,"url":"http://localhost:4569","status":1}]}
        reduce_workers = JSON.parse(response.body, symbolize_names: true)
        puts reduce_workers
        if reduce_workers[:reserved_workers].count == 0
          # 続投
          reduce_worker_url = job.map_worker_url
        else
          reduce_worker_url = reduce_workers[:reserved_workers].first[:url]
        end
        puts reduce_worker_url
        
        task_script = job.reduce_script
        task_class_name = job.reduce_class_name
        task_input_bucket_name = SimpleMapReduce.s3_intermediate_bucket_name
        task_input_file_path = "#{job.id}/#{Time.now.to_i}_map_output.txt"
        task_output_bucket_name = job.job_output_bucket_name
        task_output_directory_path = job.job_output_directory_path

        reduce_task = ::SimpleMapReduce::Server::Task.new(
                        job_id: job.id,
                        task_class_name: task_class_name,
                        task_script: task_script,
                        task_input_bucket_name: task_input_bucket_name,
                        task_input_file_path: task_input_file_path,
                        task_output_bucket_name: task_output_bucket_name,
                        task_output_directory_path: task_output_directory_path
                      )

        puts 's3 put_object start'
        local_output_cache.rewind
        s3_client.put_object(
          body: local_output_cache.read,
          bucket: reduce_task.task_input_bucket_name,
          key: reduce_task.task_input_file_path
        )
        puts 's3 put_object end'
        
        client = http_client(reduce_worker_url)
        response = client.post do |request|
          request.url('/reduce_tasks')
          request.body = reduce_task.serialize
        end
        
        puts response.inspect
        
        # TODO: Sort
      rescue => e
        puts e.inspect
        puts e.backtrace.take(10)
        # TODO: fail処理
      ensure
        local_input_cache&.delete
        local_output_cache&.delete
        self.class.send(:remove_const, task_wrapper_class_name.to_sym)
        puts 'map task end'
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
