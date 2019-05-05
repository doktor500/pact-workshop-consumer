require "sinatra/base"

require_relative "./payment_service_client"

class PaymentServiceApp < Sinatra::Base

  set :show_exceptions, false

  def initialize(app = nil, payment_service_client = PaymentServiceClient.new)
    super(app)
    @payment_service_client = payment_service_client
  end

  get "/" do
    erb :index
  end

  get "/validate-payment-method" do
    response = @payment_service_client.validate(params["payment-method"].split.join)
    @payment_method = {number: params["payment-method"], status: response["status"]}
    erb :index
  end

  not_found do
    erb :error
  end

  error 500 do
    erb :error
  end
end
