require "json"
require "payment_service_app"
require "rack/test"

RSpec.describe PaymentServiceApp do
  include Rack::Test::Methods

  let(:payment_service_client) { double() }
  let(:app) { PaymentServiceApp.new(Sinatra::Application, payment_service_client) }
  let(:payment_method) { "1234 1234" }

  it "renders a view to validate a payment method" do
    get "/"

    expect(last_response).to be_ok
    expect(last_response.body).to include("Validate payment method")
  end

  it "renders a view that contains that presents information of the payment method status" do
    allow(payment_service_client).to receive(:validate) { JSON.parse('{"status": "valid"}') }

    get "/validate-payment-method" , params = { "payment-method" => payment_method}

    expect(last_response).to be_ok
    expect(last_response.body).to include("#{payment_method} is valid")
  end

  it "returns 404 when the path is not recognized" do
    get "/invalid-path"

    expect(last_response.status).to eq(404)
  end

  it "returns 500 when an unexpecte error happens" do
    allow(payment_service_client).to receive(:validate) { raise StandardError }

    get "/validate-payment-method" , params = { "payment-method" => payment_method}

    expect(last_response.status).to eq(500)
  end
end
