# TODO Checklist

- [ ] Make `MAX_WORKER_RESERVABLE_SIZE` in `JobTracker` configurable.
- [ ] Allow `RunMapTaskWorker` to specify the number of workers when reserving reduce workers.
- [ ] Notify the job tracker if a map task fails.
- [ ] Notify the job tracker when reduce tasks succeed.
- [ ] Notify the job tracker when reduce tasks fail.
- [ ] Implement the `SimpleMapReduce::Driver::Job` class.
- [ ] Implement the `SimpleMapReduce::Driver::Config` class.
- [ ] Expand the data store implementation for persistent job and task state.
