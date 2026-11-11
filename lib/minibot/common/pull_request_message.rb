# typed: true
# frozen_string_literal: true

module Minibot
  # Title / body / branch name, in Dependabot's format so the PRs look familiar:
  #   "Bump rack from 2.2.3 to 2.2.21 in /examples/ruby-app"
  class PullRequestMessage
    BRANCH_PREFIX = "minibot"
    MAX_ADVISORIES = 10

    def initialize(dependency:, directory:, advisories_fixed: [], links: {}, strategy: nil)
      @dep = dependency
      @directory = directory
      @advisories = advisories_fixed
      @links = links
      @strategy = strategy
    end

    def title
      suffix = @directory == "/" ? "" : " in #{@directory}"
      "Bump #{@dep.name} from #{@dep.previous_version} to #{@dep.version}#{suffix}"
    end

    # Deterministic per (ecosystem, directory, dependency, version): if the branch
    # already exists, this exact PR was already opened.
    def branch_name
      [BRANCH_PREFIX, @dep.package_manager, @directory.delete_prefix("/"), "#{@dep.name}-#{@dep.version}"]
        .reject(&:empty?).join("/").squeeze("/")
    end

    # Prefix shared by every PR for this dependency, used to find superseded ones.
    def dependency_branch_prefix
      branch_name.delete_suffix("#{@dep.version}")
    end

    def commit_message
      "#{title}\n\nUpdated by minibot."
    end

    def body
      sections = ["Bumps `#{@dep.name}` from #{@dep.previous_version} to #{@dep.version}."]
      sections << requirement_section if @dep.requirements_changed?
      sections << security_section if @advisories.any?
      sections << links_section if @links.any?
      sections << "---\n_Opened by [minibot](https://github.com/MahmoudMShehata/minibot)" \
                  "#{@strategy ? " · strategy: `#{@strategy}`" : ''}_"
      sections.join("\n\n")
    end

    private

    def requirement_section
      rows = @dep.previous_requirements.zip(@dep.requirements).map do |old, new|
        "| `#{old[:file]}` | `#{old[:requirement]}` | `#{new[:requirement]}` |"
      end
      ["**Requirement changes**", "", "| File | From | To |", "|---|---|---|", *rows].join("\n")
    end

    def security_section
      shown = @advisories.sort_by(&:display_id).reverse.first(MAX_ADVISORIES)
      items = shown.map { "- [#{_1.display_id}](#{_1.url}): #{_1.summary || 'no summary'}" }
      items << "- ...and #{@advisories.size - shown.size} more" if @advisories.size > shown.size
      ["**Security:** this update fixes #{@advisories.size} known #{@advisories.size == 1 ? 'vulnerability' : 'vulnerabilities'}:",
       *items].join("\n")
    end

    def links_section
      ["**Links**", *@links.map { |label, url| "- #{label}: #{url}" }].join("\n")
    end
  end
end
