# frozen_string_literal: true

RSpec.describe Minibot::Bundler::RequirementsUpdater do
  def update(req, version) = described_class.update(req, version)

  it "leaves satisfied requirements alone (lockfile-only update)" do
    expect(update("~> 2.2", "2.2.25")).to eq("~> 2.2")
    expect(update(">= 1.0", "9.9.9")).to eq(">= 1.0")
  end

  it "bumps pessimistic constraints keeping precision" do
    expect(update("~> 12.3", "13.4.2")).to eq("~> 13.4")
    expect(update("~> 2.2.3", "3.1.4")).to eq("~> 3.1.4")
    expect(update("~> 2", "3.1.4")).to eq("~> 3")
  end

  it "moves exact pins" do
    expect(update("= 1.0.0", "1.2.0")).to eq("= 1.2.0")
  end

  it "raises upper bounds in compound requirements" do
    expect(update(">= 1.0, < 2", "2.3.0")).to eq(">= 1.0, < 3")
  end
end
