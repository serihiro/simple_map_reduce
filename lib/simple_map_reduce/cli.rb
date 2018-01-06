# frozen_string_literal: true

module SimpleMapReduce
  class Cli
    class << self
      def run_job_tracker!(config)
        assign_config_parameters(config)
        SimpleMapReduce::Server::JobTracker.run!(port: config.server_port) do
          SimpleMapReduce::Server::JobTracker.setup_job_tracker
        end
      end

      def run_job_worker!(config)
        assign_config_parameters(config)
        SimpleMapReduce::Server::JobWorker.run!(port: config.server_port) do
          SimpleMapReduce::Server::JobWorker.setup_worker
        end
      end

      private

      def assign_config_parameters(config)
        SimpleMapReduce.s3_config = config.s3_config
        SimpleMapReduce.s3_input_bucket_name = config.s3_input_bucket_name
        SimpleMapReduce.s3_intermediate_bucket_name = config.s3_intermediate_bucket_name
        SimpleMapReduce.s3_output_bucket_name = config.s3_output_bucket_name
        SimpleMapReduce.logger = config.logger
        SimpleMapReduce.job_tracker_url = config.job_tracker_url
        SimpleMapReduce.job_worker_url = config.job_worker_url
      end
    end
  end
end
