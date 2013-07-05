require 'bcrypt'
require 'securerandom'
require 'logger'

if ENV['RACK_ENV'] == 'test'
  BCRYPT_COST = BCrypt::Engine::MIN_COST
else
  BCRYPT_COST = BCrypt::Engine::DEFAULT_COST
end

require File.join(File.dirname(__FILE__), 'db')

DB.extension :pg_array, :pg_hstore, :pg_json
Sequel.extension :pg_array_ops, :pg_hstore_ops

Sequel::Model.raise_on_typecast_failure = false
Sequel::Model.plugin :auto_validations
Sequel::Model.plugin :prepared_statements
Sequel::Model.plugin :prepared_statements_associations
Sequel::Model.plugin :many_to_one_pk_lookup
Sequel::Model.plugin :forme

require './models/user'
require './models/application'
require './models/error'

if ENV['RACK_ENV'] == 'development'
  DB.loggers << Logger.new($stdout)

  if User.empty?
    u = User.create(:email=>'kaeruera', :password=>'kaeruera')
    u.add_application(:name=>'KaeruEraApp')
  end
end
