shared_examples_for "kaeruera libs" do
  it "should insert current error into database" do
    raise 'foo' rescue (e = $!; (record))
    DB[:errors].first.values_at(:application_id, :error_class, :message, :backtrace).should == [@application_id, e.class.name, e.message, e.backtrace]
  end

  it "should insert given error into database" do
    raise 'foo' rescue (e = $!)
    raise 'foo' rescue (record(:error=>e))
    DB[:errors].first.values_at(:application_id, :error_class, :message, :backtrace).should == [@application_id, e.class.name, e.message, e.backtrace]
  end

  it "should insert given params, session, and environemnt with error" do
    h = {:params=>{'a'=>'b', 'c'=>[1]}, :session=>{'a'=>'b', 'c'=>[1]}, :env=>{'a'=>'b'}}
    raise 'foo' rescue (e = $!; (record(h)))
    DB[:errors].first.values_at(:params, :session, :env).should == h.values_at(:params, :session, :env)
  end

  it "should return true" do
    raise 'foo' rescue (record.should == DB[:errors].max(:id))
  end

  it "should return exception if there was a problem inserting an error" do
    raise 'foo' rescue (record(:env=>'a').should be_a_kind_of(StandardError))
  end

  it "should return false if there is no error" do
    record.should == false
  end
end
