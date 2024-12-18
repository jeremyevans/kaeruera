# Specs

ruby = FileUtils::RUBY
ruby += ' -w' if RUBY_VERSION >= '3'
ruby += ' -W:strict_unused_block' if RUBY_VERSION >= '3.4'

desc "Run model specs"
task :model_spec do
  sh "#{ruby} spec/model_spec.rb"
end

desc "Run database_reporter specs"
task :database_reporter_spec do
  sh "#{ruby} spec/database_reporter_spec.rb"
end

desc "Run reporter specs"
task "reporter_spec" do |t|
  sh "#{ruby} spec/reporter_spec.rb"
end

desc "Run web specs"
task :web_spec do
  sh "#{ruby} spec/web_spec.rb"
end

desc "Run all specs"
task :default=>[:database_reporter_spec, :model_spec, :reporter_spec, :web_spec]

desc "Run specs with coverage"
task :reporter_spec_cov do
  ENV['COVERAGE'] = 'database'
  sh "#{ruby} spec/database_reporter_spec.rb"
  ENV['COVERAGE'] = 'web'
  sh "#{ruby} spec/reporter_spec.rb"
end

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

# Other

namespace :assets do
  desc "Precompile the assets"
  task :precompile do
    require_relative 'kaeruera_app'
    KaeruEra::App.compile_assets
  end
end

desc "Annotate Sequel models"
task "annotate" do
  ENV['RACK_ENV'] = 'development'
  require_relative 'models'
  require 'sequel/annotate'
  Sequel::Annotate.annotate(Dir['models/*.rb'], :namespace=>true)
end

desc "Run specs in CI"
task :spec_ci do
  ENV['KAERUERA_SESSION_SECRET'] = '1'*64
  ENV['KAERUERA_DATABASE_URL'] = "postgres://localhost/?user=postgres&password=postgres"
  migrate.call('test', nil)
  ENV['KAERUERA_DATABASE_URL'] = "postgres://localhost/?user=postgres&password=postgres"
  Rake::Task['default'].invoke
end
