### Requirements

- Ruby 2.4+ (It is already installed if you are using Mac OS X)
- [Docker](https://hub.docker.com/editions/community/docker-ce-desktop-mac)

### Setup the environment

Install bundler 1.17.2 if you don't have it already installed

`sudo gem install bundler -v 1.17.2`

Verify that you have the right version by running `bundler --version`

If you have a more up to date versions of bundler, unistall them with `gem uninstall bundler` until the most up to date and default version of bundler is 1.17.2

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

In this step we are going to set up a CD pipeline and we are going to use [heroku](http://heroku.com) and [circleci](https://circleci.com) for it.

First of all fork these two repositories into your github account [pact-workshop-consumer](https://github.com/doktor500/pact-workshop-consumer) [pact-workshop-provider](https://github.com/doktor500/pact-workshop-provider).

#### Create an account on heroku

Navigate to [heroku](http://heroku.com), click on the "Sign up" button and follow the instructions to create a free account.

![Heroku Step 1](https://github.com/doktor500/pact-workshop-consumer/blob/consumer-step4/resources/heroku-step1.png "Heroku Step 1")

![Heroku Step 2](https://github.com/doktor500/pact-workshop-consumer/blob/consumer-step4/resources/heroku-step2.png "Heroku Step 2")

Check your email, confirm your account and complete the registration process creating a password, save the login credentials to a safe place (browser, one password, etc.) since we will need them later.

![Heroku Step 3](https://github.com/doktor500/pact-workshop-consumer/blob/consumer-step4/resources/heroku-step3.png "Heroku Step 3")

![Heroku Step 4](https://github.com/doktor500/pact-workshop-consumer/blob/consumer-step4/resources/heroku-step4.png "Heroku Step 4")

Finally you should be able to see your heroku account dashboard

![Heroku Step 5](https://github.com/doktor500/pact-workshop-consumer/blob/consumer-step4/resources/heroku-step5.png "Heroku Step 5")

Click on the user icon on the top-right corner and select "Account settings". Scroll down and in the "API Key" section, click on the "Reveal button". Copy the API key to your clipboard and save it in a safe place, we will need it later to setup circleci and enable automatic deployments to heroku.

![Heroku Step 6](https://github.com/doktor500/pact-workshop-consumer/blob/consumer-step4/resources/heroku-step6.png "Heroku Step 6")

#### Install heroku-cli

Now let's setup heroku-cli. Navigate to [heroku-cli](https://devcenter.heroku.com/articles/heroku-cli) and follow the instructions for your operating system.

Once heroku-cli is installed, navigate to `pact-workshop-consumer` in your terminal and execute `heroku login`, follow the instructions to log in using your browser.

#### Create heroku consumer app

First, check that your `$GITHUB_USER` environment variable is set correctly by running.

```bash
echo $GITHUB_USER
```

You should see your github user name printed on the terminal, if that is not the case, make sure the environment variable is set globally and you can access it in your terminal session.

Create a heroku app by executing `heroku create pact-consumer-$GITHUB_USER`. This is the heroku app name that will be used to create the consumer app URL, so we need a unique identifier to avoid collisions.

The app URL will look like `https://pact-consumer-$GITHUB_USER.herokuapp.com/`

#### Configure heroku environment variables

The consumer app needs to to talk to the provider API that we will deploy shortly. In order to do so, we need to set an environment variable with the URL of the provider API.

In your terminal, copy paste the following command and execute it.

```bash
heroku config:set PAYMENT_SERVICE_ENDPOINT=https://pact-provider-$GITHUB_USER.herokuapp.com/
```

#### Create heroku configuration file

In the `pact-workshop-consumer` directory run `touch Procfile` to create the configuration file for heroku to be able to run the app

The content of the `Procfile` file should look like:

```
web: bundle exec rackup config.ru -p $PORT
```

#### Create an account on circleci

Now, let's create a circleci account. Navigate to [circleci](https://circleci.com), click on the "Sign up" button and follow the instructions to sign up with github.

![Circleci Step 1](https://github.com/doktor500/pact-workshop-consumer/blob/consumer-step4/resources/circleci-step1.png "Circleci Step 1")

![Circleci Step 2](https://github.com/doktor500/pact-workshop-consumer/blob/consumer-step4/resources/circleci-step2.png "Circleci Step 2")

In the "Getting started" page, select both projects in the list of projects and click the "Follow" button.

![Circleci Step 3](https://github.com/doktor500/pact-workshop-consumer/blob/consumer-step4/resources/circleci-step3.png "Circleci Step 3")

You should finally see a page similar to this

![Circleci Step 4](https://github.com/doktor500/pact-workshop-consumer/blob/consumer-step4/resources/circleci-step4.png "Circleci Step 4")

#### Configure circleci environment variables

Now, let's setup the environment variables need it to deploy the consumer application. Click on the "WORKFLOWS" icon in the left hand side menu bar, and click on the settings icon for the `pact-workshop-consumer` project.

Click on the "Environment variables" link, you should see a page similar to this:

![Circleci Step 5](https://github.com/doktor500/pact-workshop-consumer/blob/consumer-step4/resources/circleci-step5.png "Circleci Step 5")

We need to add 5 environment variables:

  - HEROKU_API_KEY
  - HEROKU_APP_NAME
  - PACT_BROKER_BASE_URL
  - PACT_BROKER_TOKEN
  - PACT_PARTICIPANT

Click on the "Add variables" button and add them one by one.

Use the `HEROKU_API_KEY` that you created in the previous step, and set the `HEROKU_APP_NAME` to `pact-consumer-$GITHUB_USER`.

If you followed the steps availabe in the [pact-workshop-broker](https://github.com/doktor500/pact-workshop-broker) repository, you can get the `PACT_BROKER_BASE_URL` and `PACT_BROKER_TOKEN` by running

```bash
echo $PACT_BROKER_BASE_URL
echo $PACT_BROKER_TOKEN
```

The `PACT_PARTICIPANT` environment variable value should be set to `PaymentServiceClient`

#### Create circleci API token

Now, let's create a circleci Personal API Token, (we will use it later to make calls to circleci API form the broker). Click in the icon on the top right hand side corner, and choose "User settings".

![Circleci Step 6](https://github.com/doktor500/pact-workshop-consumer/blob/consumer-step4/resources/circleci-step6.png "Circleci Step 6")

Create a new token and name it with something meaningful like "pact-broker", copy the token to your clipboard, and use it to create the following environment variable, we will need it later to setup the hooks in the pact-broker.

In your `~/.basrc`, `~/.zshrc`, `~/.fishrc` etc, add the following line.

```bash
export CIRCLECI_API_TOKEN=${YOUR_CIRCLECI_API_TOKEN}
```

Replacing the token with the right value.

Restart your terminal or source the file in all your active tabs `source ~/.basrc`, `source ~/.zshrc`, `source ~/.fishrc` etc.

You should be able to execute

```bash
echo $CIRCLECI_API_TOKEN
```

And see the correct value.

![Circleci Step 7](https://github.com/doktor500/pact-workshop-consumer/blob/consumer-step4/resources/circleci-step7.png "Circleci Step 7")

#### Create configuration files for circleci

Now, let's create a YAML file to configure circleci.

In the `pact-workshop-consumer` directory run `mkdir .circleci` and `touch .circleci/config.yml` to create the circle-ci configuration file.

The content of the `config.yml` file should look like:

```yaml
version: 2

jobs:
  test:
    working_directory: /tmp/project/
    docker:
      - image: circleci/ruby:2.6.3

    steps:
      - checkout

      - run:
          name: Install dependencies
          command: bundle install

      - run:
          name: Run tests
          command: |
            mkdir -p /tmp/project/test-results
            TEST_FILES="$(circleci tests glob "spec/**/*_spec.rb" | circleci tests split --split-by=timings)"

            bundle exec rspec \
              --format progress \
              --format RspecJunitFormatter \
              --out /tmp/project/test-results/rspec.xml \
              --format progress \
              $TEST_FILES

      - store_test_results:
          path: /tmp/project/test-results

      - store_artifacts:
          path: /tmp/project/test-results
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
    working_directory: /tmp/project/
    docker:
      - image: circleci/ruby:2.6.3

    steps:
      - checkout

      - run:
          name: Install dependencies
          command: bundle install

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
            git push https://heroku:${HEROKU_API_KEY}@git.heroku.com/${HEROKU_APP_NAME}.git master

            bundle exec pact-broker create-version-tag \
              --pacticipant ${PACT_PARTICIPANT} \
              --broker-base-url ${PACT_BROKER_BASE_URL} \
              --version ${CIRCLE_SHA1} \
              --tag production

workflows:
  version: 2
  pipeline:
    jobs:
      - test
      - deploy:
          requires:
            - test
          filters:
            branches:
              only: master
```

Take a look the circleci config file. You will see that there is a workflow composed by 2 different jobs.

The first job named `test` performs the following actions:

  - Checkouts the code.
  - Installs and caches the project dependencies.
  - Runs the test and stores the test results.
  - Executes the `rake pact:publish` task and publishes the results to the broker.
  - Checks if the branch can be deployed using the `can-i-deploy` command.

The second job named `deploy` depends on the `test` job and it is only executed in master branch, it performs the following actions:

  - Checkouts the code.
  - Installs the project dependencies.
  - Checks if the deployment to production can happen.
  - If the deployment can happen, it deploys and updates the `production` tag in the broker.

Navigate to the directory in where you checked out `pact-workshop-provider`, run `git clean -df && git checkout . && git checkout provider-step4` and follow the instructions in the **Provider's** readme file

### Consumer Step 5 (Deploy)

Now that the provider API is deployed, we are ready to start the journey to deploy our consumer.

#### Creating hooks in the broker to automate contract publication and verification

First of all we need to setup some hooks in the pact-broker. We are going to setup a global hook, and another hook that is specific to the branch that we are developing in this consumer app.

The first hook that we need to create is a global hook that acts on the `contract_content_changed` event. So whenever a contract is published or changed by a consumer, the `test` step for the provider's master branch will be triggered on circleci. This way, every time a contract is published or changed, we will in an automated way know if the provider already supports the functionality required by the consumer that generated the event.

To create the global hook, execute the following curl request.

```bash
curl \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $PACT_BROKER_TOKEN" \
  --request POST "$PACT_BROKER_BASE_URL/webhooks/provider/PaymentService/consumer/PaymentServiceClient" \
  --data '{
    "events": [{"name": "contract_content_changed"}],
    "request": {
      "method": "POST",
      "headers": { "Content-Type": "application/json" },
      "username": "'$CIRCLECI_API_TOKEN'",
      "url": "https://circleci.com/api/v1.1/project/github/'$GITHUB_USER'/pact-workshop-provider/tree/master",
      "body": {
        "build_parameters": {"CIRCLE_JOB": "verify"}
      }
    }
  }'
```

You should receive a successful JSON response back from the broker.

Now let's create the hook that is specific to the consumer branch that we are about to deploy.

```bash
curl \
	--header "Content-Type: application/json" \
	--header "Authorization: Bearer $PACT_BROKER_TOKEN" \
	--request POST "$PACT_BROKER_BASE_URL/webhooks/provider/PaymentService/consumer/PaymentServiceClient" \
	--data '{
	  "events": [{"name": "provider_verification_published"}],
	  "request": {
	    "method": "POST",
	    "headers": { "Content-Type": "application/json" },
	    "username": "'$CIRCLECI_API_TOKEN'",
	    "url": "https://circleci.com/api/v1.1/project/github/'$GITHUB_USER'/pact-workshop-consumer/tree/consumer-step5",
	    "body": {
	      "build_parameters": {"CIRCLE_JOB": "test"}
	    }
	  }
	}'
```

You should receive a successful JSON response back from the broker.

By creating this hook, once the provider successfully verifies the contract published by this consumer, the circleci `test` step will be run for the current branch in our consumer app and we will know that it is safe to merge this feature branch to master for deploying it.

#### Deploying a consumer's feature branch

Now, let's open a pull request on github for the current branch, a few things will happen:

- A build on circleci might be triggered for this branch if it has not previously been triggered.
- If the build is not triggered, execute `git commit --allow-empty -m "Trigger build" && git push`.
- Once the build is triggered, you should see a github yellow icon highlighting that the build is running.
- This build publishes the contract to the broker but it will fail on the verification step. You should see a github red icon highlighting that the build failed. The verification step fails because at this stage the provider has not yet verified this contract.
- Since a new contract has been published and the global hook is in place, a `contract_content_changed` event is triggered and a build for the provider's master branch will occur. You should be able to see this on circleci. Once this build step runs in the provider side, the contract will be succesfully verified.
- The provider publishes the verification of the contract to the broker and at this stage the hook for the `provider_verification_published` event will be triggered.
- A new build for the consumer's feature branch will run again and at this stage the build will finish successfully. You should see a github green icon highlighting that the feature branch can now be merged to master.

Once the build in the feature branch is green, merge the pull request to master.

Go to circleci and see how the different CD steps are executed. You should see 2 CD steps: `test` and `deploy`. Wait until all the steps have completed successfully.

Once all the steps have finshed, navigate to the following URL `https://pact-consumer-$GITHUB_USER.herokuapp.com/` replacing $GITHUB_USER with your github user name.

Congratulations, your web application is up and running and it should be able to call the provider API, you can verify it by trying to validate on the UI valid and invalid credit card numbers.
