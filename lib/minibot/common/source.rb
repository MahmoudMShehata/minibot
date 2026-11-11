# typed: true
# frozen_string_literal: true

module Minibot
  # Where the dependency files live: a GitHub repo + directory (+ branch),
  # optionally backed by a local checkout instead of the GitHub contents API.
  class Source < T::Struct
    const :repo, String
    const :directory, String, default: "/"
    const :branch, T.nilable(String), default: nil
    const :local_path, T.nilable(String), default: nil

    extend T::Sig

    sig { params(filename: String).returns(String) }
    def path_for(filename)
      File.join(directory, filename).delete_prefix("/")
    end
  end
end
