# frozen_string_literal: true

require 'msgpack'
require 'securerandom'

module SimpleMapReduce
  module Server
    class Task
      extend Forwardable
      include AASM

      attr_reader :job_id,
                  :task_class_name, :task_script,
                  :task_input_bucket_name, :task_input_file_path,
                  :task_output_bucket_name, :task_output_directory_path,
                  :worker

      delegate current_state: :aasm
      alias state current_state

      aasm do
        state :ready, initial: true
        state :in_process
        state :succeeded
        state :failed

        event :start do
          transitions ready: :in_process
        end

        event :succeed do
          transitions from: :in_process, to: :succeeded
        end

        event :fail do
          transitions from: :in_process, to: :failed
        end
      end

      def initialize(job_id:, task_class_name:, task_script:, task_input_bucket_name:, task_input_file_path:,
        task_output_bucket_name:, task_output_directory_path:, id: nil, worker: nil)
        @id = id
        @job_id = job_id
        @task_class_name = task_class_name
        @task_script = task_script
        @task_input_bucket_name = task_input_bucket_name
        @task_input_file_path = task_input_file_path
        @task_output_bucket_name = task_output_bucket_name
        @task_output_directory_path = task_output_directory_path
        @worker = worker
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

      def dump
        to_h.merge(state: state)
      end

      class << self
        def deserialize(data)
          new(MessagePack.unpack(data).transform_keys(&:to_sym))
        end
      end
    end
  end
end
