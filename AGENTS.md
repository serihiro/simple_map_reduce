# Development Guidelines

This project is a MapReduce framework implemented in Ruby. Development targets Ruby 3.4 and uses Bundler for dependency management.

## Setup

Run `bundle install` to install dependencies. You can alternatively execute `bin/setup` which runs the same command and is provided as a convenience script.

## Testing

Run tests with:

```
bundle exec rspec
```

## Linting and Formatting

Execute:

```
bundle exec rubocop
```

## Commit and PR Expectations

Use clear commit messages and open pull requests that answer the question in `.github/PULL_REQUEST_TEMPLATE.md` ("What will this PR change ?").

## Directory Structure

```
simple_map_reduce/
├── bin/           # scripts to start servers and example jobs
├── exe/           # CLI entry point used when installed as a gem
├── lib/           # library implementation
│   └── simple_map_reduce/  # framework sources
├── spec/          # RSpec tests
├── Dockerfile     # container setup for development
├── docker-compose.yml
└── ...            # other project files
```

## System Architecture Overview

The framework provides a lightweight MapReduce cluster. A **JobTracker** server coordinates jobs and workers, while **JobWorker** servers execute map and reduce tasks. Worker processes are managed via the [Rasteira](https://github.com/serihiro/rasteira) embedded job system. Input, intermediate and output data are stored in S3 compatible storage.

## File Roles

- `lib/simple_map_reduce.rb` – sets configuration and loads all components.
- `lib/simple_map_reduce/data_store_factory.rb` – creates data store instances.
- `lib/simple_map_reduce/data_stores/` – implementations for persisting job or worker state.
- `lib/simple_map_reduce/server/` – Sinatra servers and domain models for jobs, tasks and workers.
- `lib/simple_map_reduce/worker/` – background workers executed by Rasteira.
- `exe/simple_map_reduce` – Thor based CLI to run servers and sample jobs.
- `bin/*` – convenience shell scripts to launch local clusters.
- `spec/` – test suite.

## Class Roles

- `SimpleMapReduce::S3Client` – singleton wrapper of `Aws::S3::Client`.
- `SimpleMapReduce::DataStoreFactory` – factory for data store objects.
- `SimpleMapReduce::DataStores::DefaultDataStore` – no-op store used in tests.
- `SimpleMapReduce::DataStores::RemoteDataStore` – persists state via HTTP calls.
- `SimpleMapReduce::Server::Config` – holds server options such as S3 buckets and URLs.
- `SimpleMapReduce::Server::Job` – represents a MapReduce job; tracks state with AASM.
- `SimpleMapReduce::Server::Task` – represents individual map or reduce tasks.
- `SimpleMapReduce::Server::Worker` – models a worker process and its state.
- `SimpleMapReduce::Server::JobTracker` – Sinatra server orchestrating jobs and workers.
- `SimpleMapReduce::Server::JobWorker` – Sinatra server running tasks on a worker.
- Worker classes under `SimpleMapReduce::Worker` – asynchronous workers for registering tasks and executing map/reduce logic.

## Class Relationships

`JobTracker` manages `Job` and `Worker` instances. `Job` contains information about map and reduce scripts and references a `Worker` that runs map tasks. `JobWorker` wraps a `Worker` instance and receives tasks from `JobTracker`. `RunMapTaskWorker` and `RunReduceTaskWorker` use `S3Client` to download inputs and upload results. All workers update their state through data store implementations created by `DataStoreFactory`.
