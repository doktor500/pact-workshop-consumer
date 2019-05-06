require 'pact_broker/client/tasks'

PactBroker::Client::PublicationTask.new do | task |
  task.consumer_version = "0.0.1"
  task.pact_broker_base_url = "http://localhost:8000"
  task.tag_with_git_branch = true
end
