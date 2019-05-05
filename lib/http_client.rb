require "httparty"
require "uri"

class HttpClient
  def get(url)
    HTTParty.get(URI::encode(url))
  end
end
