# frozen_string_literal: true
if command = ENV.delete('COVERAGE')
  require 'simplecov'

  SimpleCov.start do
    enable_coverage :branch
    command_name command
    add_filter{|f| !f.filename.match(%r{\A#{Regexp.escape(File.dirname(__dir__))}/lib/})}
    add_group('Missing'){|src| src.covered_percent < 100}
    add_group('Covered'){|src| src.covered_percent == 100}
  end
end
