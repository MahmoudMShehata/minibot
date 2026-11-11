# typed: true
# frozen_string_literal: true

module Minibot
  # Queries https://osv.dev, which aggregates GitHub Security Advisories (GHSA),
  # RubySec, the npm advisory DB, PyPA, Go vulndb, etc. under one schema.
  # Dependabot itself reads the GitHub Advisory Database.
  class OsvClient
    URL = "https://api.osv.dev/v1/query"

    # OSV's names for ecosystems differ from package-manager names.
    ECOSYSTEMS = {
      "bundler" => "RubyGems",
      "npm" => "npm",
      "pip" => "PyPI",
      "gomod" => "Go"
    }.freeze

    def initialize(http: HTTP)
      @http = http
    end

    def advisories_for(dependency)
      ecosystem = ECOSYSTEMS.fetch(dependency.package_manager)
      body = @http.post_json(URL, {
        version: dependency.version,
        package: { name: dependency.name, ecosystem: ecosystem }
      })

      Array(body["vulns"]).map do |vuln|
        ranges = Array(vuln["affected"])
                 .select { _1.dig("package", "name") == dependency.name }
                 .flat_map { Array(_1["ranges"]) }
                 .select { _1["type"] == "ECOSYSTEM" }
                 .map { _1["events"] }

        Advisory.new(id: vuln["id"], summary: vuln["summary"],
                     aliases: Array(vuln["aliases"]), ranges: ranges)
      end
    end
  end
end
