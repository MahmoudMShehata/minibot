# frozen_string_literal: true

RSpec.describe Minibot::OsvClient do
  it "maps the package manager to the OSV ecosystem and parses ranges" do
    stub = stub_request(:post, Minibot::OsvClient::URL)
           .with(body: { version: "12.3.2", package: { name: "rake", ecosystem: "RubyGems" } }.to_json)
           .to_return(body: {
             vulns: [{
               id: "GHSA-jppv-gw3r-w3q8", summary: "OS command injection", aliases: ["CVE-2020-8130"],
               affected: [{ package: { name: "rake", ecosystem: "RubyGems" },
                            ranges: [{ type: "ECOSYSTEM", events: [{ introduced: "0" }, { fixed: "12.3.3" }] }] }]
             }]
           }.to_json)

    advisories = described_class.new.advisories_for(dependency("rake", "12.3.2", "~> 12.3"))

    expect(stub).to have_been_requested
    expect(advisories.map(&:display_id)).to eq(["CVE-2020-8130"])
    expect(advisories.first.fixed_version_for("12.3.2", Gem::Version)).to eq(Gem::Version.new("12.3.3"))
  end
end
