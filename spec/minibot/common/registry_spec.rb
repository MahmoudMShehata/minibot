# frozen_string_literal: true

RSpec.describe Minibot::Registry do
  it "registers every stage for bundler" do
    [Minibot::FileFetchers, Minibot::FileParsers, Minibot::UpdateCheckers,
     Minibot::FileUpdaters, Minibot::MetadataFinders].each do |stage|
      expect(stage.package_managers).to include("bundler")
    end
  end

  it "fails clearly for an unknown ecosystem" do
    expect { Minibot::FileParsers.for_package_manager("cargo") }
      .to raise_error(Minibot::UnsupportedEcosystem, /cargo/)
  end
end
