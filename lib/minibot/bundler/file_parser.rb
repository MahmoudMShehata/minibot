# typed: true
# frozen_string_literal: true

require "bundler"

module Minibot
  module Bundler
    # Stage 2: turn Gemfile + Gemfile.lock into Dependency objects.
    #
    # The Gemfile gives the *requirement* ("~> 2.2"); the lockfile gives the
    # *resolved version* (2.2.3). We only report top-level gems (the ones
    # declared in the Gemfile), like Dependabot's version updates do.
    #
    # SECURITY NOTE: a Gemfile is Ruby code, and evaluating it runs arbitrary code
    # from the repo being scanned. dependabot-core runs this step inside an isolated
    # helper process/container for that reason. Here it runs in-process.
    class FileParser
      def initialize(dependency_files:)
        @gemfile = dependency_files.find { _1.name == "Gemfile" }
        @lockfile = dependency_files.find { _1.name == "Gemfile.lock" }
      end

      def parse
        locked_versions = ::Bundler::LockfileParser.new(@lockfile.content)
                                                   .specs.to_h { [_1.name, _1.version.to_s] }

        declared_dependencies.filter_map do |dep|
          next unless dep.source.nil? # skip git/path gems; they have no registry version

          version = locked_versions[dep.name]
          next unless version # e.g. platform-specific gem not resolved here

          Dependency.new(
            name: dep.name,
            version: version,
            package_manager: "bundler",
            requirements: [{
              file: @gemfile.name,
              requirement: dep.requirement.to_s,
              groups: dep.groups.map(&:to_s)
            }]
          )
        end
      end

      private

      def declared_dependencies
        dsl = ::Bundler::Dsl.new
        dsl.instance_eval(@gemfile.content, @gemfile.name, 1)
        dsl.dependencies
      end
    end
  end
end
