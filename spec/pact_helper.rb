require 'pact/consumer/rspec'

Pact.service_consumer "PaymentServiceClient" do
  has_pact_with "PaymentService" do
    mock_service :payment_service do
      port 4567
    end
  end
end
