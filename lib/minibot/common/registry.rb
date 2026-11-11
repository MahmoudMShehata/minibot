# typed: true
# frozen_string_literal: true

module Minibot
  # Plugin registry, modelled on dependabot-core's
  # `Dependabot::FileParsers.register("bundler", ...)`.
  # Adding an ecosystem means registering four classes; nothing in common/ changes.
  module Registry
    def register(package_manager, klass)
      registry[package_manager] = klass
    end

    def for_package_manager(package_manager)
      registry.fetch(package_manager) do
        raise UnsupportedEcosystem, "#{name} has no class registered for '#{package_manager}'"
      end
    end

    def package_managers
      registry.keys
    end

    private

    def registry
      @registry ||= {}
    end
  end

  module FileFetchers;   extend Registry; end
  module FileParsers;    extend Registry; end
  module UpdateCheckers; extend Registry; end
  module FileUpdaters;   extend Registry; end
  module MetadataFinders; extend Registry; end
end
