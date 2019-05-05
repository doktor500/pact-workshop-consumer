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
