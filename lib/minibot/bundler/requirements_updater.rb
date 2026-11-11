# typed: true
# frozen_string_literal: true

module Minibot
  module Bundler
    # Decides how a Gemfile requirement must change to allow a new version.
    # This is Dependabot's "increase" versioning strategy:
    #
    #   "~> 2.2",          3.1.4  -> "~> 3.1"           (keep the precision)
    #   "~> 2.2.3",        3.1.4  -> "~> 3.1.4"
    #   "= 1.0.0" / "1.0", 1.2.0  -> "= 1.2.0"
    #   ">= 1.0, < 2",     2.3.0  -> ">= 1.0, < 3"
    #   ">= 1.0",          9.9    -> ">= 1.0"           (already satisfied)
    #
    # If the new version already satisfies the requirement, nothing changes and
    # the update is "lockfile-only".
    class RequirementsUpdater
      extend T::Sig

      sig { params(requirement: String, new_version: String).returns(String) }
      def self.update(requirement, new_version)
        version = Gem::Version.new(new_version)
        parts = requirement.split(",").map(&:strip)
        return requirement if Gem::Requirement.new(*parts).satisfied_by?(version)

        updated = parts.map { update_part(_1, version) }.join(", ")
        unless Gem::Requirement.new(*updated.split(",")).satisfied_by?(version)
          raise ResolutionError, "can't rewrite '#{requirement}' to allow #{new_version}"
        end

        updated
      end

      sig { params(part: String, version: Gem::Version).returns(String) }
      def self.update_part(part, version)
        op, old = Gem::Requirement.parse(part)
        case op
        when "~>"
          precision = old.segments.length
          segments = version.segments.first(precision)
          segments << 0 while segments.length < precision
          "~> #{segments.join('.')}"
        when "="
          "= #{version}"
        when "<"
          "< #{version.segments.first + 1}"
        when "<="
          "<= #{version}"
        else # ">=", ">", "!=": never block an upgrade
          part
        end
      end
    end
  end
end
