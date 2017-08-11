ENV['RACK_ENV'] = 'test'
require_relative '../models'
include KaeruEra

TRANSACTIONAL_TESTS = true
require_relative 'spec_helper'

[:errors, :applications, :users].each{|t| DB[t].delete}
raise 'foo' rescue User.create(:email=>'ke', :password=>'secret').
  add_application(:name=>'app').
  add_app_error(:error_class=>$!.class,
                :message=>$!.message,
                :env=>Sequel.pg_jsonb('grapes'=>'watermelon'),
                :params=>Sequel.pg_jsonb('banana'=>'apple'),
                :session=>Sequel.pg_jsonb('pear'=>'papaya'),
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
    Error.search({:field=>'env', :key=>'grapes'}, user_id).all.must_equal Error.all
    Error.search({:field=>'env', :key=>'foo'}, user_id).all.must_equal []
  end

  it ".search should search by env key and value" do
    Error.search({:field=>'env', :key=>'grapes', :value=>'watermelon'}, user_id).all.must_equal Error.all
    Error.search({:field=>'env', :key=>'grapes', :value=>'foo'}, user_id).all.must_equal []
  end

  it ".search should search by params key" do
    Error.search({:field=>'params', :key=>'banana'}, user_id).all.must_equal Error.all
    Error.search({:field=>'params', :key=>'foo'}, user_id).all.must_equal []
  end

  it ".search should search by params key and value" do
    Error.search({:field=>'params', :key=>'banana', :value=>'apple'}, user_id).all.must_equal Error.all
    Error.search({:field=>'params', :key=>'banana', :value=>'foo'}, user_id).all.must_equal []
  end

  it ".search should search by session key" do
    Error.search({:field=>'session', :key=>'pear'}, user_id).all.must_equal Error.all
    Error.search({:field=>'session', :key=>'foo'}, user_id).all.must_equal []
  end

  it ".search should search by session key and value" do
    Error.search({:field=>'session', :key=>'pear', :value=>'papaya'}, user_id).all.must_equal Error.all
    Error.search({:field=>'session', :key=>'pear', :value=>'foo'}, user_id).all.must_equal []
  end
  it ".search should handle non-string values" do
    Error.dataset.update(:session=>Sequel.pg_jsonb('pear'=>1))
    Error.search({:field=>'session', :key=>'pear', :value=>'1', :field_type=>'i'}, user_id).all.must_equal Error.all
    Error.search({:field=>'session', :key=>'pear', :value=>'1'}, user_id).all.must_equal []

    Error.dataset.update(:session=>Sequel.pg_jsonb('pear'=>true))
    Error.search({:field=>'session', :key=>'pear', :value=>'true', :field_type=>'b'}, user_id).all.must_equal Error.all
    Error.search({:field=>'session', :key=>'pear', :value=>'true'}, user_id).all.must_equal []

    Error.dataset.update(:session=>Sequel.pg_jsonb('pear'=>false))
    Error.search({:field=>'session', :key=>'pear', :value=>'false', :field_type=>'b'}, user_id).all.must_equal Error.all
    Error.search({:field=>'session', :key=>'pear', :value=>'false'}, user_id).all.must_equal []

    Error.dataset.update(:session=>Sequel.pg_jsonb('pear'=>nil))
    Error.search({:field=>'session', :key=>'pear', :value=>'nil', :field_type=>'n'}, user_id).all.must_equal Error.all
    Error.search({:field=>'session', :key=>'pear', :value=>'nil'}, user_id).all.must_equal []
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
