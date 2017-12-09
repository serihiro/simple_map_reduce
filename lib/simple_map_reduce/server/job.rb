require 'msgpack'

module SimpleMapReduce
  module Server
    class Job
      attr_reader :id, :map_script, :map_class_name, :reduce_script, :reduce_class_name,
                  :job_input_bucket_name, :job_input_directory_path,
                  :job_output_bucket_name, :job_output_directory_path,
                  :map_worker,
                  :status
      STATUS = {
        ready: 0,
        in_process: 1,
        succeeded: 2,
        failed: 3
      }.freeze

      STATUS.keys.each do |status|
        define_method "#{status.to_s}!".to_sym do
          @status = STATUS[status]
        end
  
        define_method "#{status.to_s}?".to_sym do
          @status == STATUS[status]
        end
      end
    
      def initialize(id: nil,
                     map_script:,
                     map_class_name:,
                     reduce_script:,
                     reduce_class_name:,
                     job_input_bucket_name:,
                     job_input_directory_path:,
                     job_output_bucket_name:,
                     job_output_directory_path:,
                     map_worker: nil,
                     status: nil)
        @id = id
        @map_script = map_script
        @map_class_name = map_class_name
        @reduce_script = reduce_script
        @reduce_class_name = reduce_class_name
        @job_input_bucket_name = job_input_bucket_name
        @job_input_directory_path = job_input_directory_path
        @job_output_bucket_name = job_output_bucket_name
        @job_output_directory_path = job_output_directory_path
        @map_worker = map_worker
        @status = status || STATUS[:ready]
      end
      
      def id
        @id ||= self.object_id
      end
      
      def to_h
        {
           id: id,
           map_script: @map_script,
           map_class_name: @map_class_name,
           reduce_script: @map_script,
           reduce_class_name: @map_script,
           job_input_bucket_name: @job_input_bucket_name,
           job_input_directory_path: @job_input_directory_path,
           job_output_bucket_name: @job_output_bucket_name,
           job_output_directory_path: @job_output_directory_path,
           status: @status
        }
      end
      
      def serialize
        to_h.to_msgpack
      end
      
      class << self
        def deserialize(data)
          new(Hash[MessagePack.unpack(data).map { |k,v|[k.to_sym, v] }])
        end
      end
    end
  end
end
