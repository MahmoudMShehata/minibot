# frozen_string_literal: true

RSpec.describe Minibot::Advisory do
  # Shape of a real OSV record with several maintained release lines.
  subject(:advisory) do
    described_class.new(
      id: "GHSA-xxxx", summary: "bad thing", aliases: ["GHSA-xxxx", "CVE-2022-1234"],
      ranges: [[{ "introduced" => "0" }, { "fixed" => "2.1.4.1" },
                { "introduced" => "2.2.0" }, { "fixed" => "2.2.3.1" },
                { "introduced" => "3.0.0" }]] # 3.x: no fix yet
    )
  end

  it "prefers the CVE id for display" do
    expect(advisory.display_id).to eq("CVE-2022-1234")
  end

  it "knows which versions are affected" do
    expect(advisory.affects?("2.1.0", Gem::Version)).to be(true)
    expect(advisory.affects?("2.1.4.1", Gem::Version)).to be(false)
    expect(advisory.affects?("2.2.3", Gem::Version)).to be(true)
    expect(advisory.affects?("3.1.0", Gem::Version)).to be(true)
  end

  it "picks the fix on the same release line" do
    expect(advisory.fixed_version_for("2.2.0", Gem::Version)).to eq(Gem::Version.new("2.2.3.1"))
    expect(advisory.fixed_version_for("1.0.0", Gem::Version)).to eq(Gem::Version.new("2.1.4.1"))
    expect(advisory.fixed_version_for("3.0.1", Gem::Version)).to be_nil
  end
end
