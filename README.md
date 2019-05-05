### Requirements

- Ruby 2.4.4 (It is already installed if you are using Mac OS X)
- [Docker](https://hub.docker.com/editions/community/docker-ce-desktop-mac)

### Setup the environment

Install bundler if you don't have it already installed

`sudo gem install bundler`

### Install dependencies

- Execute `bundle install`

### Run the tests

- Execute `rspec`

### Consumer Step 0 (Setup)

Get familiraised with the code

![System diagram](https://github.com/doktor500/pact-workshop-consumer/blob/master/resources/system-diagram.png "System diagram")

You can run this app by excuting `bundle exec rackup config.ru -p 3000` and then navigate to locahost:3000

There are two microservices in this system. A `consumer` (this repository) and a `provider`.

The "provider" is a PaymentService that validates if a credit card number is valid in the context of that system.

The "consumer" only makes requests to PaymentService to verify payment methods.

Checkout the [Provider](https://github.com/doktor500/pact-workshop-provider/) microservice, so the directory structure looks like:

    drwxr-xr-x - pact-workshop-consumer
    drwxr-xr-x - pact-workshop-provider

Run `git checkout consumer-step1` and follow the instructions in this readme file

### Consumer Step 1 (Creating the first contract)

Although all the tests are passing, there is a bug introduced on purpose in `spec/payment_service_client_spec.rb`. Can you spot it?

The PaymentService API returns a response that contains a payment method `status`, but the test has incorrectly assumed that the response contains a `state` field.

The unit test that lives in `spec/payment_service_client_spec.rb` is pretty much useless.

If there is a change in the provider API, the test will continue to pass, but the communication between the consumer and the provider will be broken.

At this stage we have 3 alternatives to workaround this issue:

  1. Create an End to End test that involves the consumer and the provider (PaymentService)
  2. Create an Integration test for the API that PaymentService is exposing
  3. Implement a Contract test

Creating and E2E test is expensive since in a CD environment you will need to have instances of both microservices running in order to execute the test.
Creating an Integration test for the API that PaymentService is exposing, is a good alternative but it has some drawbacks.

  - If the test is written in the provider side, if the API changes it is going to be difficult to make the consumer aware of the change
  - If the test is written in the consumer side, you will need an instance of the provider (PaymentService) running in order to be able to execute the test

We will explore Option 3, and we will implement a Contract test using [Pact](https://docs.pact.io/)

___

Create this file `spec/pact_helper.rb` with the following content

```ruby
require 'pact/consumer/rspec'

Pact.service_consumer "PaymentServiceClient" do
  has_pact_with "PaymentService" do
    mock_service :payment_service do
      port 4567
    end
  end
end
```

We are seting up Pact in the consumer. Pact lets the consumers define the expectations for the integration point.

Replace `spec/payment_service_client_spec.rb` with the following content in order to convert the previous unit test to a Pact contract test.

```ruby
require "pact_helper"
require "payment_service_client"

describe PaymentServiceClient, :pact => true do
  let(:payment_method) { "1234123412341234" }
  let(:response_body) do { state: :valid } end

  before do
    payment_service
      .upon_receiving("a request for validating a payment method")
      .with(method: :get, path: "/validate-payment-method/#{payment_method}")
      .will_respond_with(
        status: 200,
        headers: {"Content-Type" => "application/json"},
        body: response_body
      )
  end

  it "calls payment service to validate payment method" do
    expect(subject.validate(payment_method)).to eql({ "state" => "valid" })
  end
end
```

Run the tests with `rspec`. At this stage a new contract has been generated in the `spec/pacts` directory.
Take a look at the content of the file in JSON format that contains the contract definition.

Navigate to the directory in where you checked out `pact-workshop-provider`, run `git clean -df && git checkout . && git checkout provider-step1` and follow the instructions in the **Provider's** readme file

### Consumer Step 2 (Using provider state)

In our PaymentService API we want now to keep track of payment methods that are suspected to be fraudulent, by adding them to a list of blacklisted payment methods.

In our consumer tests, we want to verify that when we call our PaymentService with an invalid payment method, the response returned by the API states that the payment is invalid.

In order to try this scenario out, we would need somehow to have a predefined state in our PaymentService with invalid pre-registered payment methods.

Let's start defining the test from the point of view of the consumer for this scenario.

Go to `spec/payment_service_client_spec.rb` and copy paste this test suite:

```ruby
require "pact_helper"
require "payment_service_client"

describe PaymentServiceClient, :pact => true do
  context "given a valid payment method" do
    let(:valid_payment_method) { "1234123412341234" }
    let(:response_body) do { status: :valid } end
    before do
      payment_service
        .upon_receiving("a request for validating a payment method")
        .with(method: :get, path: "/validate-payment-method/#{valid_payment_method}")
        .will_respond_with(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: response_body
        )
    end

    it "the call to payment service returns a payment status response with status equal to valid" do
      expect(subject.validate(valid_payment_method)).to eql({ "status" => "valid" })
    end
  end

  context "given a black listed payment method" do
    let(:invalid_payment_method) { "9999999999999999" }
    let(:response_body) do { status: :fraud } end
    before do
      payment_service
        .given("a black listed payment method")
        .upon_receiving("a request for validating the payment method")
        .with(method: :get, path: "/validate-payment-method/#{invalid_payment_method}")
        .will_respond_with(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: response_body
        )
    end

    it "the call to payment service returns a payment status response with status equal to fraud" do
      expect(subject.validate(invalid_payment_method)).to eql({ "status" => "fraud" })
    end
  end
end
```

Take a look at the second test, note that the `before` block contains now a new `given("...")` section.

Run `rspec` in the `pact-workshop-consumer` directory in order to update the consumer pacts and see the new pact in the `spec/pacts/paymentserviceclient-paymentservice.json` file.

Navigate to the directory in where you checked out `pact-workshop-provider`, run `git clean -df && git checkout . && git checkout provider-step2` if you haven't already done so and follow the instructions in the **Provider's** readme file

### Consumer Step 3 (Working with a PACT broker)

#### Publishing contracts to the pact-broker

In the `pact-workshop-consumer` directory add `gem "pact_broker-client"` this gem to the `Gemfile`, the file should look like:

```ruby
source 'https://rubygems.org'

gem 'httparty'
gem 'rack'
gem 'rake'

group :development, :test do
  gem 'pact'
  gem 'pact_broker-client'
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

PactBroker::Client::PublicationTask.new do |task|
  task.pact_broker_base_url = PACT_BROKER_BASE_URL
  task.pact_broker_token    = PACT_BROKER_TOKEN
  task.consumer_version     = `git rev-parse HEAD`.strip
  task.tag_with_git_branch  = true
end
```

Now run `rake pact:publish` and navigate to `localhost:8000`, you should see the contract been published.

Navigate to the directory in where you checked out `pact-workshop-provider`, run `git clean -df && git checkout . && git checkout provider-step3` if you haven't already done so and follow the instructions in the **Provider's** readme file

### Consumer Step 4 (Setting up CD)

In this step we are going to set up a CD pipeline and we are going to use [circleci](https://circleci.com) for it.

First of all fork these two repositories into your github account [pact-workshop-consumer](https://github.com/doktor500/pact-workshop-consumer) [pact-workshop-provider](https://github.com/doktor500/pact-workshop-provider).

Navigate to [circleci](https://circleci.com), click on the "Sign up" button and follow the instructions to sign up with github.

![Circleci Step 1](https://github.com/doktor500/pact-workshop-consumer/blob/consumer-step4/resources/circleci-step1.png "Circleci Step 1")

![Circleci Step 2](https://github.com/doktor500/pact-workshop-consumer/blob/consumer-step4/resources/circleci-step2.png "Circleci Step 2")

In the "Getting started" page, select both projects in the list of projects and click the "Follow" button.

![Circleci Step 3](https://github.com/doktor500/pact-workshop-consumer/blob/consumer-step4/resources/circleci-step3.png "Circleci Step 3")

You should finally see a page similar to this:

![Circleci Step 4](https://github.com/doktor500/pact-workshop-consumer/blob/consumer-step4/resources/circleci-step4.png "Circleci Step 4")

Now, let's create a new Personal API Token, (we will use that later to make calls to circleci API form the broker). Click in the icon on the top right hand side corner, and choose "User settings".

![Circleci Step 5](https://github.com/doktor500/pact-workshop-consumer/blob/consumer-step4/resources/circleci-step5.png "Circleci Step 5")

Create a new token and name it with something meaningful like "pact-broker", Copy the token to your clipboard, and save it in a safe place, we will make use of it later.

![Circleci Step 6](https://github.com/doktor500/pact-workshop-consumer/blob/consumer-step4/resources/circleci-step6.png "Circleci Step 6")

Now, let's create a YAML file to configure circleci.

In the `pact-workshop-consumer` directory run `mkdir .circleci` and `touch .circleci/config.yml` to create the necessary configuration for circle-ci to work.

The content of the `config.yml` file should look like:

```yaml
version: 2

jobs:
  build:
    docker:
      - image: circleci/ruby:2.6.3

    steps:
      - checkout
      - run:
          name: Install dependencies
          command: |
            gem install bundler -v 2.0.1
            bundle update --bundler
            bundle install --jobs=4 --retry=3 --path vendor/bundle

      - run:
          name: Run tests
          command: |
            mkdir -p /tmp/test-results
            TEST_FILES="$(circleci tests glob "spec/**/*_spec.rb" | circleci tests split --split-by=timings)"

            bundle exec rspec \
              --format progress \
              --format RspecJunitFormatter \
              --out /tmp/test-results/rspec.xml \
              --format progress \
              $TEST_FILES

      - store_test_results:
          path: /tmp/test-results

      - store_artifacts:
          path: /tmp/test-results
          destination: test-results

      - run:
          name: Publish contracts
          command: rake pact:publish

      - run:
          name: Check if contracts are verified
          command: |
            bundle exec pact-broker can-i-deploy \
              --pacticipant ${PACT_PARTICIPANT} \
              --broker-base-url ${PACT_BROKER_BASE_URL} \
              --latest
  deploy:
    docker:
      - image: circleci/ruby:2.6.3

    steps:
      - checkout
      - run:
          name: Install dependencies
          command: |
            gem install bundler -v 2.0.1
            bundle update --bundler
            bundle install --jobs=4 --retry=3 --path vendor/bundle

      - run:
          name: Check if deployment can happen
          command: |
            bundle exec pact-broker can-i-deploy \
              --pacticipant ${PACT_PARTICIPANT} \
              --broker-base-url ${PACT_BROKER_BASE_URL} \
              --latest --to production

      - run:
          name: Deploy to production
          command: |
            echo "Deploying to production"

            bundle exec pact-broker create-version-tag \
              --pacticipant ${PACT_PARTICIPANT} \
              --broker-base-url ${PACT_BROKER_BASE_URL} \
              --version ${CIRCLE_SHA1} \
              --tag production

workflows:
  version: 2
  pipeline:
    jobs:
      - build
      - deploy:
          requires:
            - build
          filters:
            branches:
              only: master
```

Take a look the circleci config file. You will see that there is a workflow composed by two different jobs.
The first job named "build" performs the following actions:

  - Checkouts the code
  - Installs the project dependencies
  - Runs the test and stores the test results
  - Executes the `rake pact:publish` task and publishes the results to the broker
  - Checks if the branch can be deployed using the `can-i-deploy` command

The second job named "deploy" depends on the "build" job and it is only executed in master branch, it performs the following actions:

  - Checkouts the code
  - Installs the project dependencies
  - Checks if the deployment to production can happen
  - If the deployment can happen, it deploys and updates the "production" tag in the broker

Navigate to the directory in where you checked out `pact-workshop-provider`, run `git clean -df && git checkout . && git checkout provider-step4` and follow the instructions in the **Provider's** readme file
