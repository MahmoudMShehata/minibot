# frozen_string_literal: true

RSpec.describe Minibot::PullRequestMessage do
  let(:updated) do
    Minibot::Dependency.new(
      name: "rake", version: "13.4.2", previous_version: "12.3.2", package_manager: "bundler",
      requirements: [{ file: "Gemfile", requirement: "~> 13.4", groups: [] }],
      previous_requirements: [{ file: "Gemfile", requirement: "~> 12.3", groups: [] }]
    )
  end
  let(:advisory) { Minibot::Advisory.new(id: "GHSA-1", summary: "injection", aliases: ["CVE-2020-8130"]) }

  subject(:message) do
    described_class.new(dependency: updated, directory: "/examples/ruby-app",
                        advisories_fixed: [advisory], links: { "Changelog" => "https://x/CHANGELOG" })
  end

  it "uses Dependabot's title format" do
    expect(message.title).to eq("Bump rake from 12.3.2 to 13.4.2 in /examples/ruby-app")
  end

  it "builds a deterministic branch name" do
    expect(message.branch_name).to eq("minibot/bundler/examples/ruby-app/rake-13.4.2")
    expect(message.dependency_branch_prefix).to eq("minibot/bundler/examples/ruby-app/rake-")
  end

  it "omits the directory for the repo root" do
    msg = described_class.new(dependency: updated, directory: "/")
    expect(msg.title).to eq("Bump rake from 12.3.2 to 13.4.2")
    expect(msg.branch_name).to eq("minibot/bundler/rake-13.4.2")
  end

  it "describes requirement changes, advisories and links" do
    expect(message.body).to include("| `Gemfile` | `~> 12.3` | `~> 13.4` |")
    expect(message.body).to include("[CVE-2020-8130](https://osv.dev/vulnerability/GHSA-1): injection")
    expect(message.body).to include("Changelog: https://x/CHANGELOG")
  end
end
