require 'rasteira'
require 'faraday'

module SimpleMapReduce
  class << self
    # see https://github.com/aws/aws-sdk-ruby/blob/v2.10.100/aws-sdk-resources/lib/aws-sdk-resources/services/s3/encryption/client.rb#L182-L219
    # for detail of s3_config
    attr_accessor :s3_config
    attr_accessor :job_tracker_url
    attr_accessor :job_worker_url
    attr_writer :s3_input_bucket_name
    attr_writer :s3_output_bucket_name
    attr_writer :s3_intermediate_bucket_name
    
    def logger=
      @logger = logger
    end
    
    def logger
      @logger ||= Logger.new(STDOUT)
    end
    
    def s3_input_bucket_name
      @s3_input_bucket_name ||= 'input'
    end
    
    def s3_output_bucket_name
      @s3_output_bucket_name ||= 'output'
    end
    
    def s3_intermediate_bucket_name
      @s3_intermediate_bucket_name ||= 'intermediate'
    end
  end

  class BaseError < StandardError; end
end

require 'simple_map_reduce/version'
require 'simple_map_reduce/s3_client'
require 'simple_map_reduce/driver/config'
require 'simple_map_reduce/driver/job'
require 'simple_map_reduce/server/job'
require 'simple_map_reduce/server/task'
require 'simple_map_reduce/server/worker'
require 'simple_map_reduce/server/job_tracker'
require 'simple_map_reduce/server/job_worker'
require 'simple_map_reduce/worker/register_map_task_worker'
require 'simple_map_reduce/worker/run_map_task_worker'
require 'simple_map_reduce/worker/run_reduce_task_worker'
