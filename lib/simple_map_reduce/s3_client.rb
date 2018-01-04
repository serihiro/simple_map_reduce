# frozen_string_literal: true

require 'aws-sdk'
require 'singleton'

module SimpleMapReduce
  class S3Client
    include ::Singleton
    attr_reader :client

    def initialize
      @client = ::Aws::S3::Client.new(SimpleMapReduce.s3_config)
    end
  end
end
