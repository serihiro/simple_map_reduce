# frozen_string_literal: true

require 'bundler/setup'
require 'simple_map_reduce'
require 'rack/test'
Rack::Test.const_set(:DEFAULT_HOST, 'localhost')
require 'factory_bot'

ENV['RACK_ENV'] = 'test'
module RSpecMixin
  include Rack::Test::Methods
  def app
    described_class
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include(RSpecMixin)

  config.include FactoryBot::Syntax::Methods
  config.before(:suite) do
    FactoryBot.find_definitions
  end
end
