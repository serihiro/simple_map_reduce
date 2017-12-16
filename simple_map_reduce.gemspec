# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'simple_map_reduce/version'

Gem::Specification.new do |spec|
  spec.name          = 'simple_map_reduce'
  spec.version       = SimpleMapReduce::VERSION
  spec.authors       = ['Kazuhiro Serizawa']
  spec.email         = ['nserihiro@gmail.com']

  spec.summary       = %q{Simple MapReduce framework}
  spec.description   = %q{Simple MapReduce framework}
  spec.homepage      = 'https://github.com/serihiro/simple_map_reduce'
  spec.license       = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.15'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_runtime_dependency 'rasteira', '~> 0.1.0'
  spec.add_runtime_dependency 'sinatra', '~> 2.0.0'
  spec.add_runtime_dependency 'sinatra-contrib', '~> 2.0.0'
  spec.add_runtime_dependency 'aws-sdk', '~> 2.10.0'
  spec.add_runtime_dependency 'msgpack', '~> 1.2.0'
  spec.add_runtime_dependency 'faraday', '~> 0.13.0'
  spec.add_runtime_dependency 'aasm', '~> 4.12.0'
end
