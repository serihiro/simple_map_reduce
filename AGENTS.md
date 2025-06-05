# Development Guidelines

This project is a MapReduce framework implemented in Ruby. Development targets Ruby 3.3 and uses Bundler for dependency management.

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
