ENV['RACK_ENV'] = 'test'
$: << File.dirname(File.dirname(__FILE__))
require 'db'
require 'lib/kaeruera/reporter'
require 'spec/shared_lib_spec'

[:errors, :applications, :users].each{|t| DB[t].delete}
user_id = DB[:users].insert(:email=>'ke', :password_hash=>'secret')
application_id = DB[:applications].insert(:user_id=>user_id, :name=>'app', :token=>'1')
DB.extension :pg_array, :pg_hstore, :pg_json

describe KaeruEra::Reporter do
  def record(*a)
    @reporter.report(*a)
  end

  before(:all) do
    @reporter = KaeruEra::Reporter.new('http://127.0.0.1:25778/report_error', application_id, '1')
    @application_id = application_id
  end
  before do
    DB[:errors].delete
  end

  it_should_behave_like "kaeruera libs"
end
