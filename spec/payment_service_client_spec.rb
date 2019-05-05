require "pact_helper"
require "payment_service_client"

RSpec.describe PaymentServiceClient, pact: true do
  let(:payment_method) { "1234123412341234" }
  let(:response_body) do { status: :valid } end

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
    expect(subject.validate(payment_method)).to eql({ "status" => "valid" })
  end
end
