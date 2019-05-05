require "pact_helper"
require "payment_service_client"

RSpec.describe PaymentServiceClient, pact: true do

  context "given a valid payment method" do
    let(:valid_payment_method) { "1111222233334444" }
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
