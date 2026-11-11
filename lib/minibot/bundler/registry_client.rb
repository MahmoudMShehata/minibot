# typed: true
# frozen_string_literal: true

module Minibot
  module Bundler
    # Thin wrapper around the rubygems.org JSON API.
    class RegistryClient
      BASE = "https://rubygems.org/api/v1"

      def initialize(http: HTTP)
        @http = http
        @cache = {}
      end

      # All published (non-yanked) versions, newest first.
      def versions(name)
        @cache[[:versions, name]] ||=
          @http.get_json("#{BASE}/versions/#{name}.json").map { Gem::Version.new(_1["number"]) }
      end

      def gem_info(name)
        @cache[[:info, name]] ||= @http.get_json("#{BASE}/gems/#{name}.json")
      end
    end
  end
end
