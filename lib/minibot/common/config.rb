# typed: true
# frozen_string_literal: true

require "yaml"

module Minibot
  # Reads .github/minibot.yml, a subset of the dependabot.yml schema:
  #
  #   version: 1
  #   updates:
  #     - package-ecosystem: bundler
  #       directory: /examples/ruby-app
  #       open-pull-requests-limit: 5
  #       ignore:
  #         - dependency-name: rspec
  #         - dependency-name: rack
  #           versions: [">= 3"]
  class Config
    UpdateConfig = Struct.new(:package_manager, :directory, :open_pull_requests_limit,
                              :target_branch, :ignore, keyword_init: true) do
      # Requirement strings to exclude for a given dependency ([">= 0"] = ignore entirely).
      def ignored_versions_for(name)
        ignore.select { _1["dependency-name"] == name }
              .flat_map { Array(_1["versions"] || ">= 0") }
      end
    end

    attr_reader :updates

    def self.load(path)
      new(YAML.safe_load(File.read(path)))
    end

    def self.parse(yaml)
      new(YAML.safe_load(yaml))
    end

    def initialize(hash)
      @updates = Array(hash.fetch("updates")).map do |u|
        UpdateConfig.new(
          package_manager: u.fetch("package-ecosystem"),
          directory: u.fetch("directory", "/"),
          open_pull_requests_limit: u.fetch("open-pull-requests-limit", 5),
          target_branch: u["target-branch"],
          ignore: Array(u["ignore"])
        )
      end
    end
  end
end
