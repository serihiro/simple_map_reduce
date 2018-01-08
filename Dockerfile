FROM ruby:2.5.0

WORKDIR /app

ADD simple_map_reduce.gemspec /app/simple_map_reduce.gemspec
ADD Gemfile /app/Gemfile
ADD lib/simple_map_reduce/version.rb /app/lib/simple_map_reduce/version.rb
RUN gem install bundler
RUN bundle install -j 4 --path=vendor/bundle
