# frozen_string_literal: true
module KaeruEraLibs
  extend Minitest::Spec::DSL

  it "should insert current error into database" do
    raise 'foo' rescue (e = $!; (@reporter.report))
    KaeruEra::DB[:errors].first.values_at(:application_id, :error_class, :message, :backtrace).must_equal [@application_id, e.class.name, e.message, e.backtrace]
  end

  it "should insert given error into database" do
    raise 'foo' rescue (e = $!)
    raise 'foo' rescue (@reporter.report(:error=>e))
    KaeruEra::DB[:errors].first.values_at(:application_id, :error_class, :message, :backtrace).must_equal [@application_id, e.class.name, e.message, e.backtrace]
  end

  it "should insert given params, session, and environment with error" do
    h = {:params=>{'a'=>'b', 'c'=>[1]}, :session=>{'a'=>'b', 'c'=>[1]}, :env=>{'a'=>'b'}}
    raise 'foo' rescue @reporter.report(h)
    KaeruEra::DB[:errors].first.values_at(:params, :session, :env).must_equal h.values_at(:params, :session, :env)
  end

  it "should return id of inserted row" do
    raise 'foo' rescue (@reporter.report.must_equal DB[:errors].max(:id))
  end

  it "should return exception if there was a problem inserting an error" do
    raise 'foo' rescue (@reporter.report(:env=>'a').must_be_kind_of(StandardError)) unless @skip_exception_test
    raise 'foo' rescue (@reporter.report(true).must_be_kind_of(StandardError))
  end

  it "should return false if there is no error" do
    @reporter.report.must_equal false
  end
end
