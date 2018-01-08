# frozen_string_literal: true

FactoryBot.define do
  factory :worker, class: SimpleMapReduce::Server::Worker do
    transient do
      url 'http://localhost:4568'
    end

    initialize_with do
      SimpleMapReduce::Server::Worker.new(url: url)
    end
  end
end
