# frozen_string_literal: true

FactoryBot.define do
  factory :job, class: SimpleMapReduce::Server::Job do
    transient do
      map_script { 'WordCount' }
      map_class_name do
        <<-'EOS'
        class WordCount
          def map(input_data, output_io)
            input_data.split(' ').each do |raw_word|
              word = raw_word.strip
              next if word.empty?
              word.delete!('_=,.[]()#\'"-=~|&%')
              word.downcase!

              output_io.puts({ key: word, value: 1 }.to_json)
            end
          end
        end
        EOS
      end
      reduce_class_name { 'WordCount' }
      reduce_script do
        <<-'EOS'
        require 'json'
        class WordCount
          def reduce(input_io, output_io)
            output = Hash.new(0)
            count = 0
            input_io.each_line(chomp: true, rs: "\n") do |line|
              input = JSON.parse(line, symbolize_names: true)
              output[input[:key]] += input[:value]
              count += 1
              if count % 100 == 0
                puts "current count: #{count}"
              end
            end

            output.each do |key, value|
              output_io.puts(JSON.generate(Hash[key, value]))
            end
          end
        end
        EOS
      end
      job_input_directory_path { 'input.txt' }
      job_input_bucket_name { 'input' }
      job_output_directory_path { 'word_count' }
      job_output_bucket_name { 'output' }
    end

    initialize_with do
      SimpleMapReduce::Server::Job.new(
        map_script: map_script,
        map_class_name: map_class_name,
        reduce_script: reduce_script,
        reduce_class_name: reduce_class_name,
        job_input_directory_path: job_input_directory_path,
        job_input_bucket_name: job_input_bucket_name,
        job_output_directory_path: job_output_directory_path,
        job_output_bucket_name: job_output_bucket_name
      )
    end
  end
end
