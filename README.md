### Consumer Step 3 (Working with a PACT broker)

#### Publish contracts to the pact-broker

In the `pact-workshop-consumer` directory add `gem "pact_broker-client"` gem to the `Gemfile`, the file should look like:

```ruby
source 'https://rubygems.org'

gem 'httparty'
gem 'rack'
gem 'rake'
gem 'sinatra'

group :development, :test do
  gem 'pact'
  gem 'pact_broker-client'
  gem 'rack-test'
  gem 'rspec'
  gem 'rspec_junit_formatter'
end
```

In the `pact-workshop-consumer` directory execute `bundle install`

Also in the `pact-workshop-consumer` create a `Rakefile` with the following content in order to publish the pacts to the broker.

```ruby
require 'pact_broker/client/tasks'

PACT_BROKER_BASE_URL = ENV["PACT_BROKER_BASE_URL"] || "http://localhost:8000"
PACT_BROKER_TOKEN    = ENV["PACT_BROKER_TOKEN"]

git_commit = `git rev-parse HEAD`.strip

PactBroker::Client::PublicationTask.new do |task|
  task.pact_broker_base_url = PACT_BROKER_BASE_URL
  task.pact_broker_token    = PACT_BROKER_TOKEN
  task.consumer_version     = git_commit
  task.tag_with_git_branch  = true
end
```

If you have a broker running on [localhost](http://localhost:8000), publish the contract to the broker running `rake pact:publish` otherwise run `PACT_BROKER_BASE_URL=$PACT_BROKER_BASE_URL rake pact:publish` if you want to publish the contract to a different broker.

Navigate to the broker URL to see the contract published.

Navigate to the directory in where you checked out `pact-workshop-provider`, run `git clean -df && git checkout . && git checkout provider-step3` and follow the instructions in the **Provider's** readme file
