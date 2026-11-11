# typed: true
# frozen_string_literal: true

require "open3"
require "tmpdir"

module Minibot
  # The job loop: for each `updates:` entry in the config,
  # fetch -> parse -> (check -> update -> open PR) per dependency.
  class Runner
    def initialize(repo:, config:, client: nil, local_path: nil, dry_run: false,
                   security_only: false, out: $stdout)
      @repo = repo
      @config = config
      @client = client
      @local_path = local_path
      @dry_run = dry_run
      @security_only = security_only
      @out = out
    end

    def run
      @config.updates.each { run_update(_1) }
    end

    private

    def run_update(update_config)
      pm = update_config.package_manager
      base = update_config.target_branch || default_branch
      source = Source.new(repo: @repo, directory: update_config.directory, branch: base, local_path: @local_path)
      log "==> #{pm} in #{source.directory} (#{@repo}@#{base})#{' [security only]' if @security_only}" \
          "#{' [dry run]' if @dry_run}"

      files = FileFetchers.for_package_manager(pm).new(source: source, client: @client).files
      dependencies = FileParsers.for_package_manager(pm).new(dependency_files: files).parse
      log "    #{dependencies.size} top-level dependencies: " +
          dependencies.map { "#{_1.name} #{_1.version}" }.join(", ")

      creator = PullRequestCreator.new(client: @client, repo: @repo, base_branch: base) unless @dry_run
      open_prs = creator ? creator.open_minibot_pull_requests : []
      updater = Updater.new(dependency_files: files, update_config: update_config, security_only: @security_only)

      dependencies.each do |dep|
        if open_prs.size >= update_config.open_pull_requests_limit
          log "    limit of #{update_config.open_pull_requests_limit} open PRs reached; stopping"
          break
        end

        log "--- #{dep.name} #{dep.version} (#{dep.requirements.map { _1[:requirement] }.join('; ')})"
        result = updater.update(dep)
        unless result.updated?
          log "    skip: #{result.reason}"
          next
        end

        message = PullRequestMessage.new(
          dependency: result.dependency, directory: source.directory,
          advisories_fixed: result.advisories_fixed, strategy: result.strategy,
          links: MetadataFinders.for_package_manager(pm).new(dependency: result.dependency).links
        )
        log "    #{message.title}  [#{result.strategy}]"
        if result.advisories_fixed.any?
          ids = result.advisories_fixed.map(&:display_id).sort
          log "    fixes #{ids.size} #{ids.size == 1 ? 'advisory' : 'advisories'}:#{ids.first(5).join(', ')}#{ids.size > 5 ? ', ...' : ''}"
        end

        if @dry_run
          print_diff(files, result.files)
          next
        end

        if creator.branch_exists?(message.branch_name)
          log "    PR already exists on #{message.branch_name}"
          next
        end

        pr = creator.create(message: message, files: result.files)
        log "    opened #{pr.html_url}"
        open_prs.select { _1.head.ref.start_with?(message.dependency_branch_prefix) }
                .each { creator.supersede(_1, pr) && log("    closed superseded ##{_1.number}") }
        open_prs = open_prs.reject { _1.head.ref.start_with?(message.dependency_branch_prefix) } + [pr]
      end
    end

    def default_branch
      return "main" unless @client

      @client.repository(@repo).default_branch
    end

    def print_diff(old_files, new_files)
      new_files.each do |new_file|
        old = old_files.find { _1.name == new_file.name }
        Dir.mktmpdir do |dir|
          a = File.join(dir, "a")
          b = File.join(dir, "b")
          File.write(a, old.content)
          File.write(b, new_file.content)
          diff, = Open3.capture2("diff", "-u", "--label", "a/#{old.path}", "--label", "b/#{new_file.path}", a, b)
          @out.puts diff.gsub(/^/, "      ")
        end
      end
    end

    def log(msg)
      @out.puts msg
    end
  end
end
