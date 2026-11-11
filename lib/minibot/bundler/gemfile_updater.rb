# typed: true
# frozen_string_literal: true

module Minibot
  module Bundler
    # Rewrites the requirement strings on one `gem "name", ...` line, keeping the
    # user's quoting and formatting. Text replacement, not AST rewriting, which
    # is also how dependabot-core does it: a Gemfile is code and we want a minimal diff.
    module GemfileUpdater
      module_function

      def update(content, name, old_requirement, new_requirement)
        return content if old_requirement == new_requirement

        old_parts = old_requirement.split(",").map(&:strip)
        new_parts = new_requirement.split(",").map(&:strip)
        declaration = /^(\s*gem\s*\(?\s*["']#{Regexp.escape(name)}["'].*)$/

        content.gsub(declaration) do |line|
          old_parts.zip(new_parts).reduce(line) { |acc, (o, n)| replace_part(acc, o, n) }
        end
      end

      def replace_part(line, old_part, new_part)
        op, version = Gem::Requirement.parse(old_part)
        op_pattern = op == "=" ? "(?:=\\s*)?" : "#{Regexp.escape(op)}\\s*"
        pattern = /(["'])(\s*)#{op_pattern}#{Regexp.escape(version.to_s)}(\s*)\1/

        line.sub(pattern) do
          quote = Regexp.last_match(1)
          written_without_op = op == "=" && !Regexp.last_match(0).include?("=")
          text = written_without_op ? new_part.delete_prefix("= ") : new_part
          "#{quote}#{text}#{quote}"
        end
      end
    end
  end
end
