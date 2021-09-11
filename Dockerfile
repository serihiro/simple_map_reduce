FROM ruby:2.7.4

WORKDIR /app

ADD simple_map_reduce.gemspec /app/simple_map_reduce.gemspec
ADD Gemfile /app/Gemfile
ADD lib /app/lib
ADD bin /app/bin
ADD exe /app/exe
RUN gem install bundler
RUN bundle install
