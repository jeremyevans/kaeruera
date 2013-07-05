ENV['RACK_ENV'] = 'test'
$: << File.dirname(File.dirname(__FILE__))
require 'models'

class Spec::Example::ExampleGroup
  def execute(*args, &block)
    x = nil
    DB.transaction{x = super(*args, &block); raise Sequel::Rollback}
    x
  end
end

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
    User.first.applications.should == Application.all
  end

  it ".login_user_id should return id of user if email/password match" do
    User.login_user_id('ke', 'secret').should == user_id
  end

  it ".login_user_id should return nil if email/password do not match" do
    User.login_user_id('k', 'secret').should == nil
    User.login_user_id('ke', 'secret1').should == nil
  end

  it "#password= should change the user's password" do
    u = User.first
    u.password = 'foo'
    u.save
    User.login_user_id('ke', 'foo').should == user_id
  end
end

describe Application do
  it "should have working associations" do
    a = Application.first
    a.user.should == User.first
    a.app_errors.should == Error.all
  end

  it ".with_user should return applications for given user id" do
    Application.with_user(0).all.should == []
    Application.with_user(user_id).all.should == Application.all
  end

  it "should have token set when saving" do
    Application.first.token.should =~ /\A[a-f0-9]{40}\z/
  end
end

describe Error do
  it "should have working associations" do
    Error.first.application.should == Application.first
  end

  it ".search should search by user" do
    Error.search({}, user_id).all.should == Error.all
    Error.search({}, 0).all.should == []
  end

  it ".search should search by application" do
    Error.search({:application=>Application.first.id.to_s}, user_id).all.should == Error.all
    Error.search({:application=>'0'}, user_id).all.should == []
  end

  it ".search should search by error class" do
    Error.search({:class=>Error.first.error_class}, user_id).all.should == Error.all
    Error.search({:class=>'0'}, user_id).all.should == []
  end

  it ".search should search by error message" do
    Error.search({:message=>Error.first.message}, user_id).all.should == Error.all
    Error.search({:message=>'0'}, user_id).all.should == []
  end

  it ".search should search by status" do
    Error.search({:closed=>'0'}, user_id).all.should == Error.all
    Error.search({:closed=>'1'}, user_id).all.should == []
  end

  it ".search should search by backtrace" do
    Error.search({:backtrace=>Error.first.backtrace.first}, user_id).all.should == Error.all
    Error.search({:backtrace=>'0'}, user_id).all.should == []
  end

  it ".search should search by env key" do
    Error.search({:env_key=>'grapes'}, user_id).all.should == Error.all
    Error.search({:env_key=>'foo'}, user_id).all.should == []
  end

  it ".search should search by env key and value" do
    Error.search({:env_key=>'grapes', :env_value=>'watermelon'}, user_id).all.should == Error.all
    Error.search({:env_key=>'grapes', :env_value=>'foo'}, user_id).all.should == []
  end

  it ".search should search by params" do
    Error.search({:params=>'banana'}, user_id).all.should == Error.all
    Error.search({:params=>'foo'}, user_id).all.should == []
  end

  it ".search should search by session" do
    Error.search({:session=>'pear'}, user_id).all.should == Error.all
    Error.search({:session=>'foo'}, user_id).all.should == []
  end

  it ".search should search by time occurred" do
    today = Date.today.to_s
    tomorrow = (Date.today+1).to_s
    Error.search({:occurred_after=>today}, user_id).all.should == Error.all
    Error.search({:occurred_after=>tomorrow}, user_id).all.should == []
    Error.search({:occurred_before=>tomorrow}, user_id).all.should == Error.all
    Error.search({:occurred_before=>today}, user_id).all.should == []
    Error.search({:occurred_after=>today, :occurred_before=>tomorrow}, user_id).all.should == Error.all
    Error.search({:occurred_after=>today, :occurred_before=>today}, user_id).all.should == []
    Error.search({:occurred_after=>tomorrow, :occurred_before=>today}, user_id).all.should == []
  end

  it ".most_recent should most recent errors" do
    Error.most_recent.first.should == Error.first
    raise 'foo' rescue (Application.first.add_app_error(:error_class=>$!.class, :message=>$!.message, :backtrace=>Sequel.pg_array($!.backtrace)))
    Error.most_recent.first.should_not == Error.first
  end

  it ".dataset.open should return only errors that haven't been closed" do
    Error.dataset.open.all.should == Error.all
    Error.dataset.update(:closed=>true)
    Error.dataset.open.all.should == []
  end

  it ".with_user should return errors for given user id" do
    Error.with_user(0).all.should == []
    Error.with_user(user_id).all.should == Error.all
  end

  it "#status should state whether the error is open or closed" do
    e = Error.first
    e.status.should == 'Open'
    e.closed = true
    e.status.should == 'Closed'
  end
end
