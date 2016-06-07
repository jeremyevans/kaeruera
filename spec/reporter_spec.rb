require 'rubygems'
ENV['RACK_ENV'] = 'test'
$: << File.dirname(File.dirname(__FILE__))
$: << File.join(File.dirname(File.dirname(__FILE__)), 'lib')
require 'db'
require 'kaeruera/reporter'
require 'kaeruera/async_reporter'

include KaeruEra

require 'spec/spec_helper'
require 'spec/shared_lib_spec'

[:errors, :applications, :users].each{|t| DB[t].delete}
user_id = DB[:users].insert(:email=>'ke', :password_hash=>'secret')
application_id = DB[:applications].insert(:user_id=>user_id, :name=>'app', :token=>'1')
DB.extension :pg_array, :pg_json

describe KaeruEra::Reporter do
  before(:all) do
    @reporter = KaeruEra::Reporter.new('http://127.0.0.1:25778/report_error', application_id, '1')
    @application_id = application_id
  end
  before do
    DB[:errors].delete
  end

  include KaeruEraLibs
end

describe KaeruEra::AsyncReporter do
  before(:all) do
    @reporter = KaeruEra::AsyncReporter.new('http://127.0.0.1:25778/report_error', application_id, '1')
    def @reporter.report(opts={})
      if (r = super) == true
        sleep 0.3
        DB[:errors].max(:id)
      else
        r
      end
    end
    @skip_exception_test = true
    @application_id = application_id
  end
  before do
    DB[:errors].delete
  end

  include KaeruEraLibs
end
