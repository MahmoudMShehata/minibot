# typed: true
# frozen_string_literal: true

module Minibot
  module Bundler
    # Finds links for the PR body (source repo, changelog), like Dependabot's
    # MetadataFinders. Best-effort: a failure here should never block a PR.
    class MetadataFinder
      def initialize(dependency:, registry: RegistryClient.new)
        @dependency = dependency
        @registry = registry
      end

      def links
        info = @registry.gem_info(@dependency.name)
        meta = info["metadata"] || {}
        {
          "Source" => meta["source_code_uri"] || info["source_code_uri"] || info["homepage_uri"],
          "Changelog" => meta["changelog_uri"] || info["changelog_uri"],
          "Package" => "https://rubygems.org/gems/#{@dependency.name}/versions/#{@dependency.version}"
        }.compact
      rescue Error
        {}
      end
    end
  end
end
