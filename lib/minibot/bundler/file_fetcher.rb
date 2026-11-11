# typed: true
# frozen_string_literal: true

require "base64"

module Minibot
  module Bundler
    # Stage 1: get the manifest + lockfile.
    # Reads from a local checkout when one is given, else from the GitHub contents API
    # (what Dependabot does; it never clones the whole repo).
    class FileFetcher
      FILENAMES = %w[Gemfile Gemfile.lock].freeze

      def initialize(source:, client: nil)
        @source = source
        @client = client
      end

      def files
        FILENAMES.map do |name|
          DependencyFile.new(name: name, content: fetch(name), directory: @source.directory)
        end
      end

      private

      def fetch(name)
        if @source.local_path
          path = File.join(@source.local_path, @source.path_for(name))
          raise DependencyFileNotFound, "#{path} not found" unless File.exist?(path)

          File.read(path)
        else
          raise Error, "a GitHub client is needed to fetch remote files" unless @client

          blob = @client.contents(@source.repo, path: @source.path_for(name), ref: @source.branch)
          Base64.decode64(blob.content)
        end
      rescue Octokit::NotFound
        raise DependencyFileNotFound, "#{@source.path_for(name)} not found in #{@source.repo}"
      end
    end
  end
end
