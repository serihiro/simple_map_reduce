require 'msgpack'
require 'securerandom'
require 'forwardable'
require 'aasm'

module SimpleMapReduce
  module Server
    class Job
      extend Forwardable
      include AASM
      attr_reader :id, :map_script, :map_class_name, :reduce_script, :reduce_class_name,
                  :job_input_bucket_name, :job_input_directory_path,
                  :job_output_bucket_name, :job_output_directory_path,
                  :map_worker

      delegate :current_state => :aasm
      alias_method :state, :current_state
      
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
          transitions from: :in_process, to: :failed
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
        @map_script = map_script
        @map_class_name = map_class_name
        @reduce_script = reduce_script
        @reduce_class_name = reduce_class_name
        @job_input_bucket_name = job_input_bucket_name
        @job_input_directory_path = job_input_directory_path
        @job_output_bucket_name = job_output_bucket_name
        @job_output_directory_path = job_output_directory_path
        @map_worker = map_worker || SimpleMapReduce::Server::Worker.new(url: map_worker_url)
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
           map_worker_url: map_worker_url,
           state: state
        }
      end
      
      def serialize
        to_h.to_msgpack
      end
      
      def map_worker_url
        @map_worker&.url
      end
      
      class << self
        def deserialize(data)
          new(Hash[MessagePack.unpack(data).map { |k,v|[k.to_sym, v] }])
        end
      end
    end
  end
end
