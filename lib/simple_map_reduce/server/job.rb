# frozen_string_literal: true

require 'msgpack'
require 'securerandom'
require 'forwardable'
require 'aasm'

module SimpleMapReduce
  module Server
    class Job
      extend Forwardable
      include AASM
      attr_reader :map_script, :map_class_name, :reduce_script, :reduce_class_name,
                  :job_input_bucket_name, :job_input_directory_path,
                  :job_output_bucket_name, :job_output_directory_path,
                  :map_worker

      delegate current_state: :aasm
      alias state current_state

      aasm do
        state :ready, initial: true
        state :in_process
        state :succeeded
        state :failed

        event :start do
          transitions from: :ready, to: :in_process
        end

        event :succeeded do
          transitions from: :in_process, to: :succeeded
        end

        event :failed do
          transitions from: %i(in_process ready), to: :failed
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
                     map_worker_url: nil,
                     map_worker: nil,
                     state: nil)

        @id = id
        @map_script = map_script&.strip
        @map_class_name = map_class_name&.strip
        @reduce_script = reduce_script&.strip
        @reduce_class_name = reduce_class_name&.strip
        @job_input_bucket_name = job_input_bucket_name&.strip
        @job_input_directory_path = job_input_directory_path&.strip
        @job_output_bucket_name = job_output_bucket_name&.strip
        @job_output_directory_path = job_output_directory_path&.strip
        @map_worker = map_worker

        unless valid?
          raise ArgumentError, 'invalid Job parameters are detected'
        end

        unless state.to_s.empty?
          aasm.current_state = state.to_s
        end
      end

      def id
        @id ||= SecureRandom.uuid
      end

      def to_h
        {
          id: id,
          map_script: @map_script,
          map_class_name: @map_class_name,
          reduce_script: @reduce_script,
          reduce_class_name: @reduce_class_name,
          job_input_bucket_name: @job_input_bucket_name,
          job_input_directory_path: @job_input_directory_path,
          job_output_bucket_name: @job_output_bucket_name,
          job_output_directory_path: @job_output_directory_path,
          state: state
        }
      end

      def serialize
        to_h.to_msgpack
      end

      def map_worker_url
        @map_worker&.url
      end

      def valid?
        !@map_script.to_s.empty? &&
          !@map_class_name.to_s.empty? &&
          !@reduce_script.to_s.empty? &&
          !@reduce_class_name.to_s.empty? &&
          !@job_input_bucket_name.to_s.empty? &&
          !@job_input_directory_path.to_s.empty? &&
          !@job_output_bucket_name.to_s.empty? &&
          !@job_output_directory_path.to_s.empty?
      end

      class << self
        def deserialize(data)
          new(Hash[MessagePack.unpack(data).map { |k, v| [k.to_sym, v] }])
        end
      end
    end
  end
end
