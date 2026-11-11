# typed: true
# frozen_string_literal: true

require_relative "bundler/file_fetcher"
require_relative "bundler/file_parser"
require_relative "bundler/registry_client"
require_relative "bundler/requirements_updater"
require_relative "bundler/update_checker"
require_relative "bundler/gemfile_updater"
require_relative "bundler/file_updater"
require_relative "bundler/metadata_finder"

module Minibot
  FileFetchers.register("bundler", Bundler::FileFetcher)
  FileParsers.register("bundler", Bundler::FileParser)
  UpdateCheckers.register("bundler", Bundler::UpdateChecker)
  FileUpdaters.register("bundler", Bundler::FileUpdater)
  MetadataFinders.register("bundler", Bundler::MetadataFinder)
end
