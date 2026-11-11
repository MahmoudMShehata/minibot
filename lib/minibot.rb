# typed: true
# frozen_string_literal: true

require "sorbet-runtime"

module Minibot
  class Error < StandardError; end
  class DependencyFileNotFound < Error; end
  class ResolutionError < Error; end
  class UnsupportedEcosystem < Error; end
end

require_relative "minibot/common/registry"
require_relative "minibot/common/source"
require_relative "minibot/common/dependency_file"
require_relative "minibot/common/dependency"
require_relative "minibot/common/http"
require_relative "minibot/common/advisory"
require_relative "minibot/common/osv_client"
require_relative "minibot/common/config"
require_relative "minibot/common/pull_request_message"
require_relative "minibot/common/pull_request_creator"
require_relative "minibot/common/updater"
require_relative "minibot/common/runner"

# Ecosystems. Each one registers its classes with the registries above;
# common/ never references an ecosystem by name.
require_relative "minibot/bundler"
