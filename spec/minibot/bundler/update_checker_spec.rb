# frozen_string_literal: true

RSpec.describe Minibot::Bundler::UpdateChecker do
  let(:registry) do
    instance_double(Minibot::Bundler::RegistryClient,
                    versions: %w[14.0.0.beta1 13.4.2 13.0.0 12.3.3 12.3.2 12.3.1].map { Gem::Version.new(_1) })
  end
  let(:dep) { dependency("rake", "12.3.2", "~> 12.3") }
  let(:advisory) do
    Minibot::Advisory.new(id: "GHSA-1", aliases: ["CVE-2020-8130"],
                          ranges: [[{ "introduced" => "0" }, { "fixed" => "12.3.3" }]])
  end

  def checker(**opts) = described_class.new(dependency: dep, registry: registry, **opts)

  it "targets the latest stable release for version updates" do
    expect(checker.target_version).to eq(Gem::Version.new("13.4.2"))
  end

  it "targets the lowest fixed release for security updates" do
    c = checker(advisories: [advisory])
    expect(c).to be_vulnerable
    expect(c.target_version(security_only: true)).to eq(Gem::Version.new("12.3.3"))
  end

  it "ignores advisories that don't affect the current version" do
    safe = described_class.new(dependency: dependency("rake", "13.0.0", "~> 13.0"),
                               registry: registry, advisories: [advisory])
    expect(safe).not_to be_vulnerable
  end

  it "respects ignore rules" do
    expect(checker(ignored_versions: [">= 13"]).target_version).to eq(Gem::Version.new("12.3.3"))
  end

  it "computes widened requirements" do
    expect(checker.updated_requirements(Gem::Version.new("13.4.2")).first[:requirement]).to eq("~> 13.4")
  end
end
