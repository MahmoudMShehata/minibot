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

        # A gem can be declared more than once (e.g. in two `group` blocks).
        # Bundler merges those, so we report one dependency with all groups.
        declared_dependencies.group_by(&:name).filter_map do |name, decls|
          next unless decls.all? { _1.source.nil? } # skip git/path gems; no registry version

          version = locked_versions[name]
          next unless version # e.g. platform-specific gem not resolved here

          Dependency.new(
            name: name,
            version: version,
            package_manager: "bundler",
            requirements: [{
              file: @gemfile.name,
              requirement: decls.first.requirement.to_s,
              groups: decls.flat_map(&:groups).map(&:to_s).uniq
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
