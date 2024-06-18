# frozen_string_literal: true
begin
  require_relative '.env'
rescue LoadError
end

require 'sequel/core'

module KaeruEra
  opts = {}
  opts[:max_connections] = 1 if ENV['MULTITHREADED_TRANSACTIONAL_TEST']
  DB = Sequel.connect(ENV.delete('KAERUERA_DATABASE_URL') || ENV.delete('DATABASE_URL') || "postgres:///#{'kaeruera_test' if ENV['RACK_ENV'] == 'test'}?user=kaeruera", opts)
  Sequel.extension :pg_array, :pg_json, :pg_array_ops, :pg_json_ops
  DB.extension :pg_array, :pg_json
  DB.extension :pg_auto_parameterize
  if ENV['MULTITHREADED_TRANSACTIONAL_TEST']
    DB.extension :temporarily_release_connection
  end
end
