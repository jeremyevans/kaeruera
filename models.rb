require 'bcrypt'
require 'securerandom'
require 'logger'

require_relative 'db'
require 'sequel'

module KaeruEra
  if ENV['RACK_ENV'] == 'test'
    BCRYPT_COST = BCrypt::Engine::MIN_COST
  else
    BCRYPT_COST = BCrypt::Engine::DEFAULT_COST
  end

  Model = Class.new(Sequel::Model)
  Model.db = DB
  Model.plugin :auto_validations
  Model.plugin :prepared_statements
  Model.plugin :forme
  Model.plugin :forme_set
  Model.plugin :subclasses
  Model.plugin :pg_auto_constraint_validations
end

require_relative 'models/user'
require_relative 'models/application'
require_relative 'models/error'

if ENV['RACK_ENV'] == 'development'
  KaeruEra::DB.loggers << Logger.new($stdout)

  if KaeruEra::User.empty?
    u = KaeruEra::User.create(:email=>'kaeruera', :password=>'kaeruera')
    u.add_application(:name=>'KaeruEraApp')
  end
else
  KaeruEra::Model.freeze_descendents
  KaeruEra::DB.freeze
end
