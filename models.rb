require 'bcrypt'
require 'securerandom'
require 'logger'

module KaeruEra
  if ENV['RACK_ENV'] == 'test'
    BCRYPT_COST = BCrypt::Engine::MIN_COST
  else
    BCRYPT_COST = BCrypt::Engine::DEFAULT_COST
  end

  require ::File.expand_path('../db',  __FILE__)

  DB.extension :pg_array, :pg_json

  Sequel.extension :pg_array_ops, :pg_json_ops

  Model = Class.new(Sequel::Model)
  Model.db = DB
  Model.plugin :auto_validations
  Model.plugin :prepared_statements
  Model.plugin :forme
  Model.plugin :subclasses
end

require ::File.expand_path('../models/user',  __FILE__)
require ::File.expand_path('../models/application',  __FILE__)
require ::File.expand_path('../models/error',  __FILE__)

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
