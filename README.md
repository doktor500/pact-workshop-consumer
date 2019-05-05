### Consumer Step 2 (Using provider state)

In our PaymentService API we want now to keep track of payment methods that are suspected to be fraudulent, by adding them to a list of blacklisted payment methods.

In our consumer tests, we want to verify that when we call our PaymentService with an invalid payment method, the response returned by the API states that the payment is invalid.

In order to try this scenario out, we would need somehow to have a predefined state in our PaymentService with invalid pre-registered payment methods.

Let's start defining the test from the point of view of the consumer for this scenario.

Go to `spec/payment_service_client_spec.rb` and copy paste this test suite:

```ruby
require "pact_helper"
require "payment_service_client"

RSpec.describe PaymentServiceClient, pact: true do
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

Navigate to the directory in where you checked out `pact-workshop-provider`, run `git clean -df && git checkout . && git checkout provider-step2`.
