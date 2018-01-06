# frozen_string_literal: true

module SimpleMapReduce
  module Server
    class Config
      attr_reader :s3_config, :s3_intermediate_bucket_name, :s3_input_bucket_name, :s3_output_bucket_name,
                  :server_port, :logger, :job_tracker_url, :job_worker_url

      DEFAULT_S3_CONFIG = {
        access_key_id: 'MINIO_ACCESS_KEY',
        secret_access_key: 'MINIO_SECRET_KEY',
        endpoint: 'http://127.0.0.1:9000',
        region: 'us-east-1',
        force_path_style: true
      }.freeze
      DEFAULT_S3_INPUT_BUCKET_NAME = 'input'
      DEFAULT_S3_INTERMEDIATE_BUCKET_NAME = 'intermediate'
      DEFAULT_S3_OUTPUT_BUCKET_NAME = 'output'
      DEFAULT_SERVER_PORT = 4567

      def initialize(options)
        s3_config = Hash[options[:s3_config].to_a.map { |v| [v[0].to_sym, v[1]] }] # support ruby <= 2.4
        @s3_config = s3_config.empty? ? DEFAULT_S3_CONFIG : s3_config
        @s3_input_bucket_name = options[:s3_input_bucket_name] || DEFAULT_S3_INPUT_BUCKET_NAME
        @s3_intermediate_bucket_name = options[:s3_intermediate_bucket_name] || DEFAULT_S3_INTERMEDIATE_BUCKET_NAME
        @s3_output_bucket_name = options[:s3_output_bucket_name] || DEFAULT_S3_OUTPUT_BUCKET_NAME
        @server_port = options[:server_port] || 4567
        @logger = options[:logger] || Logger.new(STDOUT)
        @job_tracker_url = options[:job_tracker_url]
        @job_worker_url = options[:job_worker_url]
      end
    end
  end
end
