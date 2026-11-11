# typed: true
# frozen_string_literal: true

module Minibot
  # A security advisory for one package, in OSV terms.
  #
  # `ranges` is a list of event lists, e.g.
  #   [[{"introduced"=>"0"}, {"fixed"=>"2.1.4.4"}, {"introduced"=>"2.2.0"}, {"fixed"=>"2.2.6.4"}]]
  # Version strings are compared by the caller-supplied version class, because
  # version ordering is ecosystem-specific (Gem::Version vs semver vs PEP 440).
  class Advisory < T::Struct
    const :id, String
    const :summary, T.nilable(String)
    const :aliases, T::Array[String], default: []
    const :ranges, T::Array[T::Array[T::Hash[String, String]]], default: []

    extend T::Sig

    sig { returns(String) }
    def url
      "https://osv.dev/vulnerability/#{id}"
    end

    sig { returns(String) }
    def display_id
      aliases.find { _1.start_with?("CVE-") } || aliases.find { _1.start_with?("GHSA-") } || id
    end

    # Does `version` fall inside any affected [introduced, fixed) interval?
    def affects?(version, version_class)
      v = version_class.new(version)
      intervals(version_class).any? { |lo, hi| v >= lo && (hi.nil? || v < hi) }
    end

    # The fix for the interval `version` sits in (nil if none published).
    def fixed_version_for(version, version_class)
      v = version_class.new(version)
      interval = intervals(version_class).find { |lo, hi| v >= lo && (hi.nil? || v < hi) }
      interval&.last
    end

    private

    def intervals(version_class)
      ranges.flat_map do |events|
        result = []
        current_lo = nil
        events.each do |event|
          if event["introduced"]
            current_lo = version_class.new(event["introduced"] == "0" ? "0" : event["introduced"])
          elsif event["fixed"] && current_lo
            result << [current_lo, version_class.new(event["fixed"])]
            current_lo = nil
          end
        end
        result << [current_lo, nil] if current_lo # open-ended: no fix yet
        result
      end
    end
  end
end
