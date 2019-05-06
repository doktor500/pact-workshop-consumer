require 'pact_broker/client/tasks'

PACT_BROKER_BASE_URL = ENV["PACT_BROKER_BASE_URL"] || "http://localhost:8000"

PactBroker::Client::PublicationTask.new do |task|
  task.pact_broker_base_url = PACT_BROKER_BASE_URL
  task.consumer_version = `git rev-parse HEAD`
  task.tag_with_git_branch = true
end
