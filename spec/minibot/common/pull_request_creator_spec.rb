# frozen_string_literal: true

require "ostruct"

RSpec.describe Minibot::PullRequestCreator do
  let(:client) { instance_double(Octokit::Client) }
  let(:repo) { "me/app" }
  subject(:creator) { described_class.new(client: client, repo: repo, base_branch: "main") }

  let(:message) do
    instance_double(Minibot::PullRequestMessage, branch_name: "minibot/bundler/rake-13.4.2",
                                                 title: "Bump rake", body: "body", commit_message: "Bump rake")
  end
  let(:file) { Minibot::DependencyFile.new(name: "Gemfile", content: "new", directory: "/app") }

  it "builds tree -> commit -> branch -> PR through the Git Data API" do
    allow(client).to receive(:ref).with(repo, "heads/main").and_return(OpenStruct.new(object: OpenStruct.new(sha: "base")))
    allow(client).to receive(:commit).with(repo, "base")
                                     .and_return(OpenStruct.new(commit: OpenStruct.new(tree: OpenStruct.new(sha: "tree0"))))
    expect(client).to receive(:create_tree)
      .with(repo, [{ path: "app/Gemfile", mode: "100644", type: "blob", content: "new" }], base_tree: "tree0")
      .and_return(OpenStruct.new(sha: "tree1"))
    expect(client).to receive(:create_commit).with(repo, "Bump rake", "tree1", "base").and_return(OpenStruct.new(sha: "c1"))
    expect(client).to receive(:create_ref).with(repo, "heads/minibot/bundler/rake-13.4.2", "c1")
    expect(client).to receive(:create_pull_request)
      .with(repo, "main", "minibot/bundler/rake-13.4.2", "Bump rake", "body").and_return(OpenStruct.new(number: 7))
    expect(client).to receive(:add_labels_to_an_issue).with(repo, 7, ["dependencies"])

    expect(creator.create(message: message, files: [file]).number).to eq(7)
  end

  it "detects existing branches" do
    allow(client).to receive(:ref).with(repo, "heads/x").and_raise(Octokit::NotFound)
    expect(creator.branch_exists?("x")).to be(false)
  end
end
