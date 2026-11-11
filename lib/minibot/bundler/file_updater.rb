# typed: true
# frozen_string_literal: true

require "open3"
require "tmpdir"

module Minibot
  module Bundler
    # Stage 4: produce the new Gemfile + Gemfile.lock.
    #
    # The lockfile is never edited by hand: we write the files to a temp dir and
    # let Bundler's own resolver regenerate it (`bundle lock --update <gem>`).
    # This is the core idea of dependabot-core: each ecosystem shells out to its
    # *native* package manager (that's why the repo contains Go/Python/JS helpers).
    class FileUpdater
      attr_reader :resolved_version

      def initialize(dependency_files:, dependency:, new_requirements:)
        @files = dependency_files
        @dependency = dependency
        @new_requirements = new_requirements
      end

      def updated_files
        gemfile = file("Gemfile")
        lockfile = file("Gemfile.lock")

        new_gemfile = @dependency.requirements.zip(@new_requirements).reduce(gemfile.content) do |acc, (old, new)|
          GemfileUpdater.update(acc, @dependency.name, old[:requirement], new[:requirement])
        end

        new_lockfile = run_bundle_lock(new_gemfile, lockfile.content)
        @resolved_version = ::Bundler::LockfileParser.new(new_lockfile)
                                                     .specs.find { _1.name == @dependency.name }&.version&.to_s

        if @resolved_version.nil? || Gem::Version.new(@resolved_version) <= Gem::Version.new(@dependency.version)
          raise ResolutionError, "#{@dependency.name} could not be moved past #{@dependency.version}"
        end

        [gemfile.with_content(new_gemfile), lockfile.with_content(new_lockfile)]
          .reject { |f| f.content == file(f.name).content }
      end

      private

      def file(name)
        @files.find { _1.name == name } or raise DependencyFileNotFound, name
      end

      def run_bundle_lock(gemfile_content, lockfile_content)
        Dir.mktmpdir("minibot-") do |dir|
          File.write(File.join(dir, "Gemfile"), gemfile_content)
          File.write(File.join(dir, "Gemfile.lock"), lockfile_content)

          env = { "BUNDLE_GEMFILE" => File.join(dir, "Gemfile"),
                  "BUNDLE_FROZEN" => "false", "BUNDLE_DEPLOYMENT" => "false" }
          # with_unbundled_env: don't let minibot's own bundle leak into the child.
          output, status = ::Bundler.with_unbundled_env do
            Open3.capture2e(env, "bundle", "lock", "--update", @dependency.name, chdir: dir)
          end
          raise ResolutionError, output.lines.last(8).join unless status.success?

          File.read(File.join(dir, "Gemfile.lock"))
        end
      end
    end
  end
end
