ENV['RACK_ENV'] = 'test'
$: << File.dirname(File.dirname(__FILE__))
require 'db'
require 'lib/kaeruera/database_reporter'
require 'spec/shared_lib_spec'

class Spec::Example::ExampleGroup
  def execute(*args, &block)
    x = nil
    DB.transaction{x = super(*args, &block); raise Sequel::Rollback}
    x
  end
end

[:errors, :applications, :users].each{|t| DB[t].delete}
user_id = DB[:users].insert(:email=>'ke', :password_hash=>'secret')
application_id = DB[:applications].insert(:user_id=>user_id, :name=>'app', :token=>'1')

describe KaeruEra::DatabaseReporter do
  before(:all) do
    @reporter = KaeruEra::DatabaseReporter.new(DB, 'ke', 'app')
    @application_id = application_id
  end

  it_should_behave_like "kaeruera libs"
end

describe KaeruEra::DatabaseReporter do
  after(:all) do
    DB[:errors].delete
  end

  it "should accept connection string in addition to database object" do
    reporter = KaeruEra::DatabaseReporter.new(DB.uri, 'ke', 'app')
    raise 'foo' rescue (reporter.report.should == DB[:errors].max(:id))
  end if DB.uri && DB.opts[:orig_opts].empty?

  it "should raise ArgumentError if the application cannot be located" do
    proc{KaeruEra::DatabaseReporter.new(DB, 'k', 'app')}.should raise_error(KaeruEra::DatabaseReporter::Error)
    proc{KaeruEra::DatabaseReporter.new(DB, 'ke', 'ap')}.should raise_error(KaeruEra::DatabaseReporter::Error)
  end
end
