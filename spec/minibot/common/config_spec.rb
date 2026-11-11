# frozen_string_literal: true

RSpec.describe Minibot::Config do
  it "parses a dependabot.yml-style config" do
    config = described_class.parse(<<~YAML)
      version: 1
      updates:
        - package-ecosystem: bundler
          directory: /app
          ignore:
            - dependency-name: rails
            - dependency-name: rack
              versions: [">= 3"]
    YAML
    update = config.updates.first

    expect(update.package_manager).to eq("bundler")
    expect(update.directory).to eq("/app")
    expect(update.open_pull_requests_limit).to eq(5)
    expect(update.ignored_versions_for("rails")).to eq([">= 0"])
    expect(update.ignored_versions_for("rack")).to eq([">= 3"])
    expect(update.ignored_versions_for("rake")).to eq([])
  end
end
