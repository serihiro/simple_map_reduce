# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleMapReduce::Server::JobTracker do
  before :each do
    SimpleMapReduce::Server::JobTracker.instance_variable_set(:@jobs, nil)
    SimpleMapReduce::Server::JobTracker.instance_variable_set(:@workers, nil)
  end

  describe '#post /jobs' do
    subject { post('/jobs', params.to_json, 'CONTENT_TYPE' => 'application/json') }

    before :each do
      dummy_workers = [SimpleMapReduce::Server::Worker.new(url: 'http://loccalhost:4570')]
      allow(SimpleMapReduce::Server::JobTracker).to receive(:fetch_available_workers).and_return(dummy_workers)

      dummy_job_manager = Class.new do
        def enqueue_job!(*args)
          # do nothing
        end
      end
      allow(SimpleMapReduce::Server::JobTracker).to receive(:job_manager).and_return(dummy_job_manager.new)
    end

    context 'with valid params' do
      let(:params) do
        job = build(:job)
        {
          map_script: job.map_script,
          map_class_name: job.map_class_name,
          reduce_script: job.reduce_script,
          reduce_class_name: job.reduce_class_name,
          job_input_directory_path: job.job_input_directory_path,
          job_input_bucket_name: job.job_input_bucket_name,
          job_output_directory_path: job.job_output_directory_path,
          job_output_bucket_name: job.job_output_bucket_name
        }
      end

      it 'responds 200' do
        expect(subject.status).to eq 200
      end

      it 'stores the job' do
        expect do
          subject
        end.to change { SimpleMapReduce::Server::JobTracker.instance_variable_get(:@jobs) }.from(nil)
        stored_jobs = SimpleMapReduce::Server::JobTracker.instance_variable_get(:@jobs)
        expect(stored_jobs.size).to eq 1
      end
    end

    context 'with invalid params' do
      let(:params) do
        job = build(:job)
        {
          reduce_script: job.reduce_script,
          reduce_class_name: job.reduce_class_name,
          job_input_directory_path: job.job_input_directory_path,
          job_input_bucket_name: job.job_input_bucket_name,
          job_output_directory_path: job.job_output_directory_path,
          job_output_bucket_name: job.job_output_bucket_name
        }
      end

      it 'responds 400' do
        expect(subject.status).to eq 400
      end

      it 'does not store the job' do
        expect { subject }.not_to change { SimpleMapReduce::Server::JobTracker.instance_variable_get(:@jobs) }
      end
    end

    context 'when unexpected error occurs' do
      before :each do
        allow(SimpleMapReduce::Server::JobTracker).to receive(:job_manager).and_raise(StandardError)
      end

      let(:params) do
        job = build(:job)
        {
          map_script: job.map_script,
          map_class_name: job.map_class_name,
          reduce_script: job.reduce_script,
          reduce_class_name: job.reduce_class_name,
          job_input_directory_path: job.job_input_directory_path,
          job_input_bucket_name: job.job_input_bucket_name,
          job_output_directory_path: job.job_output_directory_path,
          job_output_bucket_name: job.job_output_bucket_name
        }
      end

      it 'responds 500' do
        expect(subject.status).to eq 500
      end
    end
  end

  describe '#get /jobs/:id' do
    subject { get("/jobs/#{job_id}", nil, 'CONTENT_TYPE' => 'application/json') }

    context 'when the specified job exists' do
      before :each do
        @job = build(:job)
        jobs = { @job.id => @job }
        SimpleMapReduce::Server::JobTracker.instance_variable_set(:@jobs, jobs)
      end
      let(:job_id) { @job.id }

      it 'responds 200' do
        expect(subject.status).to eq 200
      end

      it 'responds job' do
        body = JSON.parse(subject.body, symbolize_names: true)
        expect(body[:job][:id]).to eq @job.id
      end
    end

    context 'when the specified job does not exist' do
      let(:job_id) { 'kagamin' }
      it 'responds 404' do
        expect(subject.status).to eq 404
      end
    end
  end

  describe '#get /jobs' do
    subject { get('/jobs', nil, 'CONTENT_TYPE' => 'application/json') }

    context 'some jobs exists' do
      before :each do
        @job = build(:job)
        jobs = { @job.id => @job }
        SimpleMapReduce::Server::JobTracker.instance_variable_set(:@jobs, jobs)
      end

      it 'responds 200' do
        expect(subject.status).to eq 200
      end

      it 'responds 200' do
        body = JSON.parse(subject.body, symbolize_names: true)
        expect(body.size).to eq 1
        expect(body[0][:id]).to eq @job.id
      end
    end

    context 'no jobs exists' do
      it 'responds 200' do
        expect(subject.status).to eq 200
      end

      it 'responds empty array' do
        body = JSON.parse(subject.body, symbolize_names: true)
        expect(body).to eq([])
      end
    end
  end

  describe '#post /workers' do
    subject { post('/workers', params.to_json, 'CONTENT_TYPE' => 'application/json') }

    context 'with valid params' do
      let(:params) { { url: 'http://localhost:4568' } }
      it 'responds 200' do
        expect(subject.status).to eq 200
      end

      it 'responds worker id' do
        body = JSON.parse(subject.body, symbolize_names: true)
        expect(body[:id]).not_to eq nil
      end
    end

    context 'with invalid params' do
      let(:params) { { url: 'nyanko' } }
      it 'respodns 400' do
        expect(subject.status).to eq 400
      end
    end
  end

  describe '#get /workers/:id' do
    subject { get("/workers/#{worker_id}", nil, 'CONTENT_TYPE' => 'application/json') }
    before :each do
      @worker = build(:worker)
      workers = { @worker.id => @worker }
      SimpleMapReduce::Server::JobTracker.instance_variable_set(:@workers, workers)
    end

    context 'when the specified worker exists' do
      let(:worker_id) { @worker.id }
      it 'responds 200' do
        expect(subject.status).to eq 200
      end

      it 'responds the worker id' do
        body = JSON.parse(subject.body, symbolize_names: true)
        expect(body[:worker][:id]).to eq @worker.id
      end
    end

    context 'when the specified worker does not exist' do
      let(:worker_id) { 'hitagi_senjogahara' }
      it 'responds 404' do
        expect(subject.status).to eq 404
      end
    end
  end

  describe '#put /workers/:id' do
    subject { put("/workers/#{worker_id}", params.to_json, 'CONTENT_TYPE' => 'application/json') }
    before :each do
      @worker = build(:worker)
      workers = { @worker.id => @worker }
      SimpleMapReduce::Server::JobTracker.instance_variable_set(:@workers, workers)
    end

    context 'with valid params' do
      let(:params) { { event: 'reserve' } }

      context 'when the specified worker exists' do
        let(:worker_id) { @worker.id }
        it 'responds 200' do
          expect(subject.status).to eq 200
        end

        it 'responds the worker id' do
          body = JSON.parse(subject.body, symbolize_names: true)
          expect(body[:worker][:id]).to eq @worker.id
          expect(body[:worker][:state]).to eq 'reserved'
        end

        it 'updates the state of the worker' do
          expect do
            subject
          end.to change { SimpleMapReduce::Server::JobTracker.instance_variable_get(:@workers).values.last.state }
                   .from(:ready).to(:reserved)
        end
      end

      context 'when the specified worker does not exist' do
        let(:worker_id) { 'hitagi_senjogahara' }
        it 'responds 404' do
          expect(subject.status).to eq 404
        end
      end
    end

    context 'with invalid params' do
      let(:worker_id) { @worker.id }
      let(:params) { { event: 'noja' } }
      it 'responds 400' do
        expect(subject.status).to eq 400
      end
    end
  end

  describe '#post /workers/reserve' do
    subject { post('/workers/reserve', params.to_json, 'CONTENT_TYPE' => 'application/json') }

    context 'when there are some ready workers' do
      before :each do
        workers = build_list(:worker, 2)
        workers = Hash[workers.map { |w| [w.id, w] }]
        SimpleMapReduce::Server::JobTracker.instance_variable_set(:@workers, workers)
      end

      context 'and specify 1 as the worker_size' do
        let(:params) { { worker_size: 1 } }

        it 'responds 200' do
          expect(subject.status).to eq 200
        end

        it 'responds 1 worker' do
          body = JSON.parse(subject.body, symbolize_names: true)
          expect(body[:reserved_workers].size).to eq 1
        end
      end

      context 'and specify 2 as the worker_size' do
        let(:params) { { worker_size: 2 } }

        it 'responds 200' do
          expect(subject.status).to eq 200
        end

        it 'responds 2 workers' do
          body = JSON.parse(subject.body, symbolize_names: true)
          expect(body[:reserved_workers].size).to eq 2
        end
      end

      context 'and specify 3 as the worker_size' do
        let(:params) { { worker_size: 3 } }

        it 'responds 200' do
          expect(subject.status).to eq 200
        end

        it 'responds 2 workers' do
          body = JSON.parse(subject.body, symbolize_names: true)
          expect(body[:reserved_workers].size).to eq 2
        end
      end

      context 'and specify -1 as the worker_size' do
        let(:params) { { worker_size: -1 } }

        it 'responds 200' do
          expect(subject.status).to eq 200
        end

        it 'responds 1 worker' do
          body = JSON.parse(subject.body, symbolize_names: true)
          expect(body[:reserved_workers].size).to eq 1
        end
      end
    end

    context 'when there are no ready workers' do
      let(:params) { { worker_size: 2 } }
      it 'responds 200' do
        expect(subject.status).to eq 200
      end

      it 'responds 1 worker' do
        body = JSON.parse(subject.body, symbolize_names: true)
        expect(body[:reserved_workers].size).to eq 0
      end
    end
  end

  describe '#get /workers' do
    subject { get("/workers", nil, 'CONTENT_TYPE' => 'application/json') }

    context 'when there are some workers' do
      before :each do
        @worker = build(:worker)
        workers = { @worker.id => @worker }
        SimpleMapReduce::Server::JobTracker.instance_variable_set(:@workers, workers)
      end

      it 'responds 200' do
        expect(subject.status).to eq 200
      end

      it 'responds workers' do
        body = JSON.parse(subject.body, symbolize_names: true)
        expect(body.size).to eq 1
        expect(body.first[:id]).to eq @worker.id
      end
    end

    context 'when there are no workers' do
      it 'responds 200' do
        expect(subject.status).to eq 200
      end

      it 'responds empty array' do
        body = JSON.parse(subject.body, symbolize_names: true)
        expect(body).to eq([])
      end
    end
  end
end
