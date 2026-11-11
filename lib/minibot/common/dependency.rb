# typed: true
# frozen_string_literal: true

module Minibot
  # Same shape as Dependabot::Dependency.
  #
  # `requirements` holds one entry per manifest that declares the dependency:
  #   { file: "Gemfile", requirement: "~> 2.2", groups: ["default"] }
  # `version` is what the lockfile resolved to.
  class Dependency < T::Struct
    Requirement = T.type_alias { T::Hash[Symbol, T.untyped] }

    const :name, String
    const :version, T.nilable(String)
    const :requirements, T::Array[Requirement]
    const :package_manager, String
    const :previous_version, T.nilable(String), default: nil
    const :previous_requirements, T.nilable(T::Array[Requirement]), default: nil

    extend T::Sig

    sig { returns(T::Boolean) }
    def top_level?
      requirements.any?
    end

    sig { returns(T::Boolean) }
    def requirements_changed?
      !previous_requirements.nil? && previous_requirements != requirements
    end
  end
end
