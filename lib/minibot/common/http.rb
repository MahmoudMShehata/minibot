# typed: true
# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Minibot
  module HTTP
    USER_AGENT = "minibot (+https://github.com/MahmoudMShehata/minibot)"

    module_function

    def get_json(url)
      request(Net::HTTP::Get.new(URI(url)))
    end

    def post_json(url, body)
      req = Net::HTTP::Post.new(URI(url))
      req["Content-Type"] = "application/json"
      req.body = JSON.generate(body)
      request(req)
    end

    def request(req)
      uri = req.uri
      req["User-Agent"] = USER_AGENT
      req["Accept"] = "application/json"
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                                open_timeout: 10, read_timeout: 30) do |http|
        http.request(req)
      end
      raise Error, "#{req.method} #{uri} failed: #{res.code}" unless res.is_a?(Net::HTTPSuccess)

      JSON.parse(res.body)
    end
  end
end
