# frozen_string_literal: true

require "minibot"
require "webmock/rspec"

module FixtureHelpers
  def bundler_files(gemfile: nil, lockfile: nil)
    dir = File.expand_path("fixtures/bundler", __dir__)
    [
      Minibot::DependencyFile.new(name: "Gemfile", content: gemfile || File.read("#{dir}/Gemfile"), directory: "/app"),
      Minibot::DependencyFile.new(name: "Gemfile.lock", content: lockfile || File.read("#{dir}/Gemfile.lock"), directory: "/app")
    ]
  end

  def dependency(name, version, requirement, pm: "bundler")
    Minibot::Dependency.new(name: name, version: version, package_manager: pm,
                            requirements: [{ file: "Gemfile", requirement: requirement, groups: ["default"] }])
  end
end

RSpec.configure do |config|
  config.include FixtureHelpers
  config.disable_monkey_patching!
  config.order = :random

  # Tests tagged :network run the real `bundle lock` against rubygems.org.
  # Skip them with: bundle exec rspec --tag ~network
  config.around(:each, :network) do |example|
    WebMock.allow_net_connect!
    example.run
  ensure
    WebMock.disable_net_connect!
  end
end
