require 'rubygems'
ENV['RACK_ENV'] = 'test'
$: << File.dirname(File.dirname(__FILE__))
require 'models'

TRANSACTIONAL_TESTS = true
require 'spec/spec_helper'

[:errors, :applications, :users].each{|t| DB[t].delete}
raise 'foo' rescue User.create(:email=>'ke', :password=>'secret').
  add_application(:name=>'app').
  add_app_error(:error_class=>$!.class,
                :message=>$!.message,
                :env=>Sequel.hstore({'grapes'=>'watermelon'}),
                :params=>Sequel.pg_json({'banana'=>'apple'}),
                :session=>Sequel.pg_json({'pear'=>'papaya'}),
                :backtrace=>Sequel.pg_array($!.backtrace))
user_id = User.first.id

describe User do
  it "should have working associations" do
    User.first.applications.must_equal Application.all
  end

  it "#password= should change the user's password" do
    u = User.first
    u.password = 'foo'
    u.save
    u.refresh
    BCrypt::Password.new(u.refresh.password_hash).must_be :==, 'foo'
  end
end

describe Application do
  it "should have working associations" do
    a = Application.first
    a.user.must_equal User.first
    a.app_errors.must_equal Error.all
  end

  it ".with_user should return applications for given user id" do
    Application.with_user(0).all.must_equal []
    Application.with_user(user_id).all.must_equal Application.all
  end

  it "should have token set when saving" do
    Application.first.token.must_match /\A[a-f0-9]{40}\z/
  end
end

describe Error do
  it "should have working associations" do
    Error.first.application.must_equal Application.first
  end

  it ".search should search by user" do
    Error.search({}, user_id).all.must_equal Error.all
    Error.search({}, 0).all.must_equal []
  end

  it ".search should search by application" do
    Error.search({:application=>Application.first.id.to_s}, user_id).all.must_equal Error.all
    Error.search({:application=>'0'}, user_id).all.must_equal []
  end

  it ".search should search by error class" do
    Error.search({:class=>Error.first.error_class}, user_id).all.must_equal Error.all
    Error.search({:class=>'0'}, user_id).all.must_equal []
  end

  it ".search should search by error message" do
    Error.search({:message=>Error.first.message}, user_id).all.must_equal Error.all
    Error.search({:message=>'0'}, user_id).all.must_equal []
  end

  it ".search should search by status" do
    Error.search({:closed=>'0'}, user_id).all.must_equal Error.all
    Error.search({:closed=>'1'}, user_id).all.must_equal []
  end

  it ".search should search by backtrace" do
    Error.search({:backtrace=>Error.first.backtrace.first}, user_id).all.must_equal Error.all
    Error.search({:backtrace=>'0'}, user_id).all.must_equal []
  end

  it ".search should search by env key" do
    Error.search({:env_key=>'grapes'}, user_id).all.must_equal Error.all
    Error.search({:env_key=>'foo'}, user_id).all.must_equal []
  end

  it ".search should search by env key and value" do
    Error.search({:env_key=>'grapes', :env_value=>'watermelon'}, user_id).all.must_equal Error.all
    Error.search({:env_key=>'grapes', :env_value=>'foo'}, user_id).all.must_equal []
  end

  it ".search should search by params" do
    Error.search({:params=>'banana'}, user_id).all.must_equal Error.all
    Error.search({:params=>'foo'}, user_id).all.must_equal []
  end

  it ".search should search by session" do
    Error.search({:session=>'pear'}, user_id).all.must_equal Error.all
    Error.search({:session=>'foo'}, user_id).all.must_equal []
  end

  it ".search should search by time occurred" do
    today = Date.today.to_s
    tomorrow = (Date.today+1).to_s
    Error.search({:occurred_after=>today}, user_id).all.must_equal Error.all
    Error.search({:occurred_after=>tomorrow}, user_id).all.must_equal []
    Error.search({:occurred_before=>tomorrow}, user_id).all.must_equal Error.all
    Error.search({:occurred_before=>today}, user_id).all.must_equal []
    Error.search({:occurred_after=>today, :occurred_before=>tomorrow}, user_id).all.must_equal Error.all
    Error.search({:occurred_after=>today, :occurred_before=>today}, user_id).all.must_equal []
    Error.search({:occurred_after=>tomorrow, :occurred_before=>today}, user_id).all.must_equal []
  end

  it ".most_recent should most recent errors" do
    Error.most_recent.first.must_equal Error.first
    raise 'foo' rescue (Application.first.add_app_error(:error_class=>$!.class, :message=>$!.message, :backtrace=>Sequel.pg_array($!.backtrace)))
    Error.most_recent.first.wont_equal Error.first
  end

  it ".dataset.open should return only errors that haven't been closed" do
    Error.dataset.open.all.must_equal Error.all
    Error.dataset.update(:closed=>true)
    Error.dataset.open.all.must_equal []
  end

  it ".with_user should return errors for given user id" do
    Error.with_user(0).all.must_equal []
    Error.with_user(user_id).all.must_equal Error.all
  end

  it "#status should state whether the error is open or closed" do
    e = Error.first
    e.status.must_equal 'Open'
    e.closed = true
    e.status.must_equal 'Closed'
  end
end
