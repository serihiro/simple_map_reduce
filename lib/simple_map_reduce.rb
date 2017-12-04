require 'rasteira'

require 'simple_map_reduce/version'
require 'simple_map_reduce/s3_client'
require 'simple_map_reduce/driver/config'
require 'simple_map_reduce/driver/job'
require 'simple_map_reduce/server/job'
require 'simple_map_reduce/server/worker'
require 'simple_map_reduce/server/job_tracker'
require 'simple_map_reduce/server/job_worker'
require 'simple_map_reduce/worker/register_map_task_worker'

module SimpleMapReduce
  class << self
    # see https://github.com/aws/aws-sdk-ruby/blob/master/gems/aws-sdk-s3/lib/aws-sdk-s3/client.rb#L79-L195
    # for detail of config
    def config(config)
      @s3_config = config
    end
  
    def s3_config
      @s3_config
    end

    def s3_config=(s3_config)
      @s3_config = s3_config
    end
  end
  
  class BaseError < StandardError; end
end
