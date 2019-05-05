require "http_client"
require "payment_service_client"

RSpec.describe PaymentServiceClient do
  let(:response_body) do { state: :valid } end
  let(:response) { double("Response", :success? => true, :body => response_body.to_json) }

  it "validates payment method" do
    http_client = HttpClient.new
    allow(http_client).to receive(:get) { response }
    payment_service_client = PaymentServiceClient.new(http_client)

    expect(payment_service_client.validate("1234 1234 1234 1234")).to eq({ "state" => "valid" })
  end
end
