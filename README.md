[![Gem Version](https://badge.fury.io/rb/simple_map_reduce.svg)](https://badge.fury.io/rb/simple_map_reduce)

# SimpleMapReduce
This is a [MapReduce](https://research.google.com/archive/mapreduce.html) distributed framework written in Ruby.
This project is an experimental project. So all the specifications will be changed suddenly.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'simple_map_reduce'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install simple_map_reduce

## Quick start in local environment with minio

### 1. Start minio server

```sh
$ docker run -p 9000:9000 -p 9001:9001  \
-e "MINIO_ROOT_USER=MINIO_ACCESS_KEY" -e "MINIO_ROOT_PASSWORD=MINIO_SECRET_KEY" -e "MINIO_REGION=us-east-1" \
minio/minio server /data --console-address :9001
```

### 2. Start job tracker

```sh
$ bundle exec simple_map_reduce run_job_tracker! \
  --job-tracker-url=http://job_tracker:4567 \
  --server-port=4567 \
  --s3_config=access_key_id:'MINIO_ACCESS_KEY' \
              secret_access_key:'MINIO_SECRET_KEY' \
              endpoint:'http://127.0.0.1:9000' \
              region:'us-east-1' \
              force_path_style:true
```

### 3. Start job worker(s)

```sh
$ bundle exec simple_map_reduce run_job_worker! \
  --job-tracker-url=http://localhost:4567 \
  --job-worker-url=http://localhost:4568 \
  --server-port=4568 \
  --s3_config=access_key_id:'MINIO_ACCESS_KEY' \
              secret_access_key:'MINIO_SECRET_KEY' \
              endpoint:'http://127.0.0.1:9000' \
              region:'us-east-1' \
              force_path_style:true
```

### 4. Generate and upload test data

```sh
$ bundle exec simple_map_reduce generate_lorem_text_data --upload=true
```

### 5. Execute word count job

```sh
$ bundle exec simple_map_reduce execute_word_count
```

## Quick start in Docker Compose

- You can setup a simple_map_reduce cluster by docker compose.

```sh
$ clone git@github.com:serihiro/simple_map_reduce.git
$ cd simple_map_reduce
$ docker compose up
```

- You can execute word count sample by executing following commands

```sh
$ docker compose exec job_tracker bundle exec simple_map_reduce generate_lorem_text_data --upload=true
$ docker compose exec job_tracker bundle exec simple_map_reduce execute_word_count
```

## Motivation of this project
I would have liked to lean the theory of distributed systems, big data processing, and MapReduce algorhythm.
In my experiences, I believed that an implementation of them is the best way to learn them.
So I decided to create an experimental implementation, and keep adding new features in order to get an practical experiences of the theories.

## Development

After checking out the repo, run `bin/setup` (or `bundle install`) to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/simple_map_reduce. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the SimpleMapReduce project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/simple_map_reduce/blob/master/CODE_OF_CONDUCT.md).
