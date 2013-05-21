require 'sequel'
require 'bcrypt'
require 'securerandom'
require 'logger'

Sequel.extension :pg_array, :pg_hstore, :pg_json, :pg_array_ops, :pg_hstore_ops

DB = Sequel.connect(ENV['DATABASE_URL'] || 'postgres:///?user=kaeruera')

DB.extension :pg_array, :pg_hstore, :pg_json

BCRYPT_COST = BCrypt::Engine::MIN_COST
Sequel::Model.raise_on_typecast_failure = false
Sequel::Model.plugin :auto_validations
Sequel::Model.plugin :prepared_statements
Sequel::Model.plugin :prepared_statements_associations
Sequel::Model.plugin :many_to_one_pk_lookup

require './models/user'
require './models/application'
require './models/error'

DB.loggers << Logger.new($stdout)

if User.empty?
  u = User.create(:email=>'jeremy', :password=>'123456')
  u.add_application(:name=>'kaeruera')
end

