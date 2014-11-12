require "rake"

# Specs

begin
  require "spec/rake/spectask"

  task :default=>[:database_reporter_spec, :reporter_spec, :model_spec, :web_spec]

  desc "Run model specs"
  Spec::Rake::SpecTask.new("model_spec") do |t|
    t.spec_files = ["spec/model_spec.rb"]
  end

  desc "Run database_reporter specs"
  Spec::Rake::SpecTask.new("database_reporter_spec") do |t|
    t.spec_files = ["spec/database_reporter_spec.rb"]
  end

  desc "Run reporter specs"
  task "reporter_spec" do |t|
    sh %{echo > spec/unicorn.test.log}
    begin
      sh %{#{FileUtils::RUBY} -S unicorn -c spec/unicorn.test.conf -D config.ru}
      sh %{#{FileUtils::RUBY} -S spec spec/reporter_spec.rb}
    ensure
      sh %{kill `cat spec/unicorn.test.pid`}
    end
  end

  desc "Run web specs"
  Spec::Rake::SpecTask.new("web_spec") do |t|
    t.spec_files = ["spec/web_spec.rb"]
  end
rescue LoadError
end

# Migrations

migrate = lambda do |env, version|
  ENV['RACK_ENV'] = env
  require './db'
  require 'logger'
  Sequel.extension :migration
  DB.loggers << Logger.new($stdout)
  Sequel::Migrator.apply(DB, 'migrate', version)
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
  Sequel::Migrator.apply(DB, 'migrate')
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
  Sequel::Migrator.apply(DB, 'migrate')
end

desc "Migrate production database to latest version"
task :production_up do
  migrate.call('production', nil)
end

# Assets

namespace :assets do
  desc "Precompile the assets"
  task :precompile do
    require './kaeruera_app'
    KaeruEra::App.compile_assets
  end
end
