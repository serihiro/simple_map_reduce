# frozen_string_literal: true

require 'msgpack'
require 'securerandom'

module SimpleMapReduce
  module Server
    class Task
      attr_reader :job_id,
                  :task_class_name, :task_script,
                  :task_input_bucket_name, :task_input_file_path,
                  :task_output_bucket_name, :task_output_directory_path,
                  :worker, :status
      STATUS = {
        ready: 0,
        in_process: 1,
        succeeded: 2,
        failed: 3
      }.freeze

      STATUS.each_key do |status|
        define_method "#{status}!".to_sym do
          @status = STATUS[status]
        end

        define_method "#{status}?".to_sym do
          @status == STATUS[status]
        end
      end

      def initialize(id: nil,
                     job_id:,
                     task_class_name:,
                     task_script:,
                     task_input_bucket_name:,
                     task_input_file_path:,
                     task_output_bucket_name:,
                     task_output_directory_path:,
                     worker: nil,
                     status: nil)
        @id = id
        @job_id = job_id
        @task_class_name = task_class_name
        @task_script = task_script
        @task_input_bucket_name = task_input_bucket_name
        @task_input_file_path = task_input_file_path
        @task_output_bucket_name = task_output_bucket_name
        @task_output_directory_path = task_output_directory_path
        @worker = worker
        @status = status || STATUS[:ready]
      end

      def id
        @id ||= SecureRandom.uuid
      end

      def to_h
        {
          id: id,
          job_id: @job_id,
          task_class_name: @task_class_name,
          task_script: @task_script,
          task_input_bucket_name: @task_input_bucket_name,
          task_input_file_path: @task_input_file_path,
          task_output_bucket_name: @task_output_bucket_name,
          task_output_directory_path: @task_output_directory_path
        }
      end

      def serialize
        to_h.to_msgpack
      end

      class << self
        def deserialize(data)
          new(Hash[MessagePack.unpack(data).map { |k, v| [k.to_sym, v] }])
        end
      end
    end
  end
end
