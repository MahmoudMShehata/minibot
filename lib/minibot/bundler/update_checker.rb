# typed: true
# frozen_string_literal: true

module Minibot
  module Bundler
    # Stage 3: is there something to update to?
    #
    # Two modes, like Dependabot:
    #   * version updates:  target = latest allowed release
    #   * security updates: target = lowest release that fixes every advisory
    #
    # This does NOT prove the target resolves alongside the other gems; the
    # FileUpdater finds that out by running Bundler's resolver. (dependabot-core
    # resolves here instead, so it can report "latest_resolvable_version".)
    class UpdateChecker
      attr_reader :dependency, :advisories

      def initialize(dependency:, advisories: [], ignored_versions: [], registry: RegistryClient.new)
        @dependency = dependency
        @advisories = advisories.select { _1.affects?(dependency.version, Gem::Version) }
        @ignored = ignored_versions.map { Gem::Requirement.new(*_1.split(",")) }
        @registry = registry
      end

      def current_version
        Gem::Version.new(dependency.version)
      end

      def vulnerable?
        advisories.any?
      end

      def advisories_affecting(version)
        advisories.select { _1.affects?(version, Gem::Version) }
      end

      def latest_version
        candidates.max
      end

      # Highest "fixed in" across all advisories; nil if any advisory has no fix yet.
      def lowest_security_fix_version
        return nil unless vulnerable?

        fixes = advisories.map { _1.fixed_version_for(dependency.version, Gem::Version) }
        return nil if fixes.any?(&:nil?)

        floor = fixes.max
        candidates.select { _1 >= floor }.min
      end

      def target_version(security_only: false)
        target = security_only ? lowest_security_fix_version : latest_version
        target if target && target > current_version
      end

      def updated_requirements(target)
        dependency.requirements.map do |req|
          req.merge(requirement: RequirementsUpdater.update(req[:requirement], target.to_s))
        end
      end

      private

      def candidates
        @registry.versions(dependency.name).reject do |v|
          (v.prerelease? && !current_version.prerelease?) ||
            @ignored.any? { |req| req.satisfied_by?(v) }
        end
      end
    end
  end
end
