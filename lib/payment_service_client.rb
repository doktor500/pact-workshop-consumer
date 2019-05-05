require "json"

require_relative "./http_client"

class PaymentServiceClient
  PAYMENT_SERVICE_ENDPOINT = ENV["PAYMENT_SERVICE_ENDPOINT"] || "http://localhost:4567"

  def initialize(http_client = HttpClient.new)
    @http_client = http_client
  end

  def validate(payment_method)
    response = @http_client.get("#{PAYMENT_SERVICE_ENDPOINT}/validate-payment-method/#{payment_method}")
    if response.success? then JSON.parse(response.body) end
  end
end
