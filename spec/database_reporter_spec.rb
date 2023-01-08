ENV['RACK_ENV'] = 'test'
require_relative '../db'
require_relative 'coverage_helper'
require_relative '../lib/kaeruera/database_reporter'

TRANSACTIONAL_TESTS = true
require_relative 'spec_helper'
require_relative 'shared_lib_spec'
require_relative 'model_freeze'

include KaeruEra

[:errors, :applications, :users].each{|t| DB[t].delete}

describe KaeruEra::DatabaseReporter do
  before(:all) do
    user_id = DB[:users].insert(:email=>'ke', :password_hash=>'secret')
    application_id = DB[:applications].insert(:user_id=>user_id, :name=>'app', :token=>'1')
    @reporter = KaeruEra::DatabaseReporter.new(DB, 'ke', 'app')
    @application_id = application_id
  end

  include KaeruEraLibs

  it "should raise ArgumentError if the application cannot be located" do
    proc{KaeruEra::DatabaseReporter.new(DB, 'k', 'app')}.must_raise(KaeruEra::DatabaseReporter::Error)
    proc{KaeruEra::DatabaseReporter.new(DB, 'ke', 'ap')}.must_raise(KaeruEra::DatabaseReporter::Error)
  end

  describe KaeruEra::DatabaseReporter do
    def around_all
      yield
    end

    def after_all
      [:errors, :applications, :users].each{|t| DB[t].delete}
    end

    it "should accept connection string in addition to database object" do
      reporter = KaeruEra::DatabaseReporter.new(DB.uri, 'ke', 'app')
      raise 'foo' rescue (reporter.report.must_equal DB[:errors].max(:id))
    end if DB.uri && DB.opts[:orig_opts].empty?
  end
end
