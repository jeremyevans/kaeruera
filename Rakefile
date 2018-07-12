require "rake"

# Specs

desc "Run model specs"
task :model_spec do
  sh "#{FileUtils::RUBY} spec/model_spec.rb"
end

desc "Run database_reporter specs"
task :database_reporter_spec do
  sh "#{FileUtils::RUBY} spec/database_reporter_spec.rb"
end


desc "Run reporter specs"
task "reporter_spec" do |t|
  sh %{echo > spec/unicorn.test.log}
  begin
    ENV['KAERUERA_SESSION_SECRET'] = '1'*64
    unicorn_bin = File.basename(FileUtils::RUBY).sub(/\Aruby/, 'unicorn')
    sh %{#{FileUtils::RUBY} -S #{unicorn_bin} -c spec/unicorn.test.conf -D config.ru}
    sh "#{FileUtils::RUBY} spec/reporter_spec.rb"
  ensure
    sh %{kill `cat spec/unicorn.test.pid`}
  end
end

desc "Run web specs"
task :web_spec do
  sh "#{FileUtils::RUBY} spec/web_spec.rb"
end

desc "Run all specs"
task :default=>[:database_reporter_spec, :model_spec, :reporter_spec, :web_spec]

# Migrations

migrate = lambda do |env, version|
  ENV['RACK_ENV'] = env
  require_relative 'db'
  require 'logger'
  Sequel.extension :migration
  KaeruEra::DB.loggers << Logger.new($stdout)
  Sequel::Migrator.apply(KaeruEra::DB, 'migrate', version)
end

desc "Migrate test database to latest version"
task :test_up do
  migrate.call('test', nil)
end

desc "Migrate test database all the way down"
task :test_down do
  migrate.call('test', 0)
end

desc "Migrate test database all the way down and then back up"
task :test_bounce do
  migrate.call('test', 0)
  Sequel::Migrator.apply(KaeruEra::DB, 'migrate')
end

desc "Migrate development database to latest version"
task :dev_up do
  migrate.call('development', nil)
end

desc "Migrate development database to latest version"
task :dev_down do
  migrate.call('development', 0)
end

desc "Migrate development database all the way down and then back up"
task :dev_bounce do
  migrate.call('development', 0)
  Sequel::Migrator.apply(KaeruEra::DB, 'migrate')
end

desc "Migrate production database to latest version"
task :production_up do
  migrate.call('production', nil)
end

# Assets

namespace :assets do
  desc "Precompile the assets"
  task :precompile do
    require_relative 'kaeruera_app'
    KaeruEra::App.compile_assets
  end
end
