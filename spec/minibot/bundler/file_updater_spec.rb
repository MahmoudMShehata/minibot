# frozen_string_literal: true

# Runs the real Bundler resolver against rubygems.org.
RSpec.describe Minibot::Bundler::FileUpdater, :network do
  def run(dep, new_requirement)
    updater = described_class.new(
      dependency_files: bundler_files, dependency: dep,
      new_requirements: [dep.requirements.first.merge(requirement: new_requirement)]
    )
    [updater.updated_files, updater.resolved_version]
  end

  it "widens the Gemfile and regenerates the lockfile" do
    files, version = run(dependency("rake", "12.3.2", "~> 12.3"), "~> 13.0")
    gemfile = files.find { _1.name == "Gemfile" }
    lockfile = files.find { _1.name == "Gemfile.lock" }

    expect(Gem::Version.new(version)).to be >= Gem::Version.new("13.0")
    expect(gemfile.content).to include(%(gem "rake", "~> 13.0"))
    expect(lockfile.content).to include("rake (#{version})")
    expect(lockfile.content).to include("rake (~> 13.0)")
  end

  it "raises ResolutionError when another gem blocks the update" do
    # sinatra 2.1 requires rack ~> 2.2, so rack 3 can't resolve.
    expect { run(dependency("rack", "2.2.3", "~> 2.2"), "~> 3.1") }
      .to raise_error(Minibot::ResolutionError)
  end
end
