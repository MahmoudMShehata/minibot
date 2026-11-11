# typed: true
# frozen_string_literal: true

module Minibot
  # Runs stages 3 + 4 for one dependency, using whichever ecosystem classes are
  # registered for its package manager.
  #
  # Update strategies, tried in order:
  #   1. :widen          - change the manifest requirement to allow the target
  #                        (e.g. "~> 2.2" -> "~> 3.1") and re-resolve.
  #   2. :lockfile_only  - keep the requirement, only move the lockfile as far as
  #                        it allows. Fallback when (1) conflicts with another
  #                        dependency, e.g. sinatra 2.x pinning rack ~> 2.2.
  class Updater
    Result = Struct.new(:status, :dependency, :files, :advisories_fixed, :strategy, :reason,
                        keyword_init: true) do
      def updated? = status == :updated
    end

    def initialize(dependency_files:, update_config:, security_only: false, osv: OsvClient.new)
      @files = dependency_files
      @config = update_config
      @security_only = security_only
      @osv = osv
      @pm = update_config.package_manager
    end

    def update(dependency)
      ignored = @config.ignored_versions_for(dependency.name)
      return skip(dependency, "ignored by config") if ignored.include?(">= 0")

      checker = UpdateCheckers.for_package_manager(@pm).new(
        dependency: dependency, advisories: advisories_for(dependency), ignored_versions: ignored
      )
      return skip(dependency, "not vulnerable") if @security_only && !checker.vulnerable?

      target = checker.target_version(security_only: @security_only)
      return skip(dependency, @security_only ? "no fixed version published" : "up to date") unless target

      errors = []
      strategies(checker, target).each do |strategy, new_requirements|
        updater = FileUpdaters.for_package_manager(@pm).new(
          dependency_files: @files, dependency: dependency, new_requirements: new_requirements
        )
        files = updater.updated_files
        resolved = updater.resolved_version
        still_vulnerable = checker.advisories_affecting(resolved)
        if @security_only && still_vulnerable.any?
          errors << "#{strategy}: #{resolved} is still vulnerable"
          next
        end

        return Result.new(
          status: :updated, strategy: strategy, files: files,
          advisories_fixed: checker.advisories - still_vulnerable,
          dependency: Dependency.new(
            name: dependency.name, package_manager: @pm,
            version: resolved, requirements: new_requirements,
            previous_version: dependency.version, previous_requirements: dependency.requirements
          )
        )
      rescue ResolutionError => e
        errors << "#{strategy}: #{e.message.strip.lines.last&.strip}"
      end

      skip(dependency, "can't resolve #{target}: #{errors.join(' | ')}")
    end

    private

    def strategies(checker, target)
      current = checker.dependency.requirements
      widened = checker.updated_requirements(target)
      return [[:lockfile_only, current]] if widened == current # target already allowed

      [[:widen, widened], [:lockfile_only, current]]
    rescue ResolutionError
      [[:lockfile_only, checker.dependency.requirements]]
    end

    def advisories_for(dependency)
      @osv.advisories_for(dependency)
    rescue Error => e
      warn "  ! advisory lookup failed for #{dependency.name}: #{e.message}"
      []
    end

    def skip(dependency, reason)
      Result.new(status: :skipped, dependency: dependency, reason: reason)
    end
  end
end
