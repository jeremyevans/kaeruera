# frozen_string_literal: true
if command = ENV.delete('COVERAGE')
  require 'simplecov'

  SimpleCov.start do
    command_name command
    merge_timeout 600
    coverage :line
    coverage :branch
    cover "lib/**/*.rb"
    group('Missing'){|src| src.covered_percent < 100}
  end
end
