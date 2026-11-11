# typed: true
# frozen_string_literal: true

require "octokit"

module Minibot
  # Opens the PR purely through the GitHub API (Git Data API: tree -> commit ->
  # ref), with no local clone or `git push`. That is how Dependabot works too: it
  # scales to many repos without checkouts.
  class PullRequestCreator
    LABELS = %w[dependencies].freeze

    def initialize(client:, repo:, base_branch:)
      @client = client
      @repo = repo
      @base = base_branch
    end

    def open_minibot_pull_requests
      @client.pull_requests(@repo, state: "open")
             .select { _1.head.ref.start_with?("#{PullRequestMessage::BRANCH_PREFIX}/") }
    end

    def branch_exists?(branch)
      @client.ref(@repo, "heads/#{branch}")
      true
    rescue Octokit::NotFound
      false
    end

    def create(message:, files:, labels: LABELS)
      base_sha = @client.ref(@repo, "heads/#{@base}").object.sha
      base_tree = @client.commit(@repo, base_sha).commit.tree.sha

      tree = @client.create_tree(
        @repo,
        files.map { { path: _1.path, mode: "100644", type: "blob", content: _1.content } },
        base_tree: base_tree
      )
      commit = @client.create_commit(@repo, message.commit_message, tree.sha, base_sha)
      @client.create_ref(@repo, "heads/#{message.branch_name}", commit.sha)

      pr = @client.create_pull_request(@repo, @base, message.branch_name, message.title, message.body)
      begin
        @client.add_labels_to_an_issue(@repo, pr.number, labels)
      rescue Octokit::Error => e
        warn "  ! could not label ##{pr.number}: #{e.message}"
      end
      pr
    end

    # Close an older PR for the same dependency, as Dependabot does
    # ("Superseded by #42").
    def supersede(old_pr, new_pr)
      @client.add_comment(@repo, old_pr.number, "Superseded by ##{new_pr.number}.")
      @client.close_pull_request(@repo, old_pr.number)
      @client.delete_branch(@repo, old_pr.head.ref)
    rescue Octokit::Error => e
      warn "  ! could not close superseded ##{old_pr.number}: #{e.message}"
    end
  end
end
