# frozen_string_literal: true

RSpec.describe Minibot::Bundler::FileParser do
  subject(:dependencies) { described_class.new(dependency_files: bundler_files).parse }

  it "returns top-level gems with lockfile versions and Gemfile requirements" do
    expect(dependencies.map { [_1.name, _1.version, _1.requirements.first[:requirement]] }).to eq([
      ["rack", "2.2.3", "~> 2.2"],
      ["sinatra", "2.1.0", "~> 2.1"],
      ["rake", "12.3.2", "~> 12.3"],
      ["rspec", "3.10.0", "~> 3.10"]
    ])
  end

  it "records groups" do
    expect(dependencies.find { _1.name == "rspec" }.requirements.first[:groups]).to eq(%w[development test])
  end

  it "skips transitive dependencies" do
    expect(dependencies.map(&:name)).not_to include("rack-protection", "tilt")
  end

  it "skips git-sourced gems" do
    gemfile = File.read(File.expand_path("../../fixtures/bundler/Gemfile", __dir__)) +
              %(gem "private_gem", git: "https://example.com/private_gem.git"\n)
    names = described_class.new(dependency_files: bundler_files(gemfile: gemfile)).parse.map(&:name)
    expect(names).not_to include("private_gem")
  end
end
