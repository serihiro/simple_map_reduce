module SimpleMapReduce
  module Worker
    class RunMapTaskWorker
      def perform(job)
        self.class.class_eval(job.map_script)
        map_task = self.class.const_get(job.map_class_name, false).new
        unless map_task.respond_to?(:map)
          # TODO: notify job_tracker
          return
        end
        
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
        
        
        # local_output_cacheのファイルを１行ずつ読み出してpartitioningして別ファイルに保存した後に別workerにぶん投げるよ
      
      rescue => e
        # TODO: fail処理
      ensure
        local_input_cache&.delete
        local_output_cache&.delete
        puts 'map task end'
      end
      
      def s3_client
        SimpleMapReduce::S3Client.instance.client
      end
    end
  end
end
