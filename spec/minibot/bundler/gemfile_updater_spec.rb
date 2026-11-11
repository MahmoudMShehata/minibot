# frozen_string_literal: true

RSpec.describe Minibot::Bundler::GemfileUpdater do
  def update(content, name, from, to) = described_class.update(content, name, from, to)

  it "rewrites only the matching gem line" do
    gemfile = %(gem "rake", "~> 12.3"\ngem "rake-compiler", "~> 12.3"\n)
    expect(update(gemfile, "rake", "~> 12.3", "~> 13.4"))
      .to eq(%(gem "rake", "~> 13.4"\ngem "rake-compiler", "~> 12.3"\n))
  end

  it "keeps single quotes and trailing options" do
    expect(update(%(  gem 'rack', '~> 2.2', require: false), "rack", "~> 2.2", "~> 3.1"))
      .to eq(%(  gem 'rack', '~> 3.1', require: false))
  end

  it "handles bare versions (implicit =)" do
    expect(update(%(gem "puma", "5.0.0"), "puma", "= 5.0.0", "= 6.4.0")).to eq(%(gem "puma", "6.4.0"))
  end

  it "handles compound requirements" do
    expect(update(%(gem "x", ">= 1.0", "< 2"), "x", ">= 1.0, < 2", ">= 1.0, < 3"))
      .to eq(%(gem "x", ">= 1.0", "< 3"))
  end
end
