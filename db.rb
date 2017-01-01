require 'sequel'
module KaeruEra; end

begin
  load File.join(File.dirname(__FILE__), 'db_config.rb')
rescue LoadError
  KaeruEra::DB = Sequel.connect(ENV['KAERUERA_DATABASE_URL'] || ENV['DATABASE_URL'] || "postgres:///#{'kaeruera_test' if ENV['RACK_ENV'] == 'test'}?user=kaeruera", :identifier_mangling=>false)
end
KaeruEra::DB.extension(:freeze_datasets)
