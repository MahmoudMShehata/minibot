# typed: true
# frozen_string_literal: true

module Minibot
  class DependencyFile < T::Struct
    const :name, String
    const :content, String
    const :directory, String, default: "/"

    extend T::Sig

    sig { returns(String) }
    def path
      File.join(directory, name).delete_prefix("/")
    end

    sig { params(new_content: String).returns(DependencyFile) }
    def with_content(new_content)
      DependencyFile.new(name: name, content: new_content, directory: directory)
    end
  end
end
