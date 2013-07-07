require 'rubygems'
ENV['RACK_ENV'] = 'test'
require 'capybara'
require 'capybara/dsl'
require 'capybara/rspec/matchers'
require 'rack/test'

$: << File.dirname(File.dirname(__FILE__))
require 'models'

[:errors, :applications, :users].each{|t| DB[t].delete}
raise 'foo' rescue User.create(:email=>'kaeruera', :password=>'secret').
  add_application(:name=>'KaeruEraApp').
  add_app_error(:error_class=>$!.class,
                :message=>$!.message,
                :env=>Sequel.hstore('grapes'=>'watermelon'),
                :params=>Sequel.pg_json('banana'=>'apple'),
                :session=>Sequel.pg_json('pear'=>'papaya'),
                :backtrace=>Sequel.pg_array($!.backtrace))
error_id = DB[:errors].max(:id).to_s

require 'kaeruera_app'

Capybara.app = KaeruEra::App

class Spec::Example::ExampleGroup
  include Rack::Test::Methods
  include Capybara::DSL
  include Capybara::RSpecMatchers
  
  def execute(*args, &block)
    x = nil
    DB.transaction{x = super(*args, &block); raise Sequel::Rollback}
    x
  end

  after do
    Capybara.reset_sessions!
    Capybara.use_default_driver
  end

  def app
    KaeruEra::App
  end

  def login
    visit('/')
    fill_in 'email', :with=>'kaeruera'
    fill_in 'password', :with=>'secret'
    click_on 'Login'
  end
end

describe KaeruEra do
  it "should not allow invalid logins" do
    visit('/')
    fill_in 'email', :with=>'k'
    fill_in 'password', :with=>'secret'
    click_on 'Login'
    page.html.should =~ /No matching email\/password/
    fill_in 'email', :with=>'ke'
    fill_in 'password', :with=>'secet'
    click_on 'Login'
    page.html.should =~ /No matching email\/password/
  end
end

describe KaeruEra do
  before do
    login
  end

  it "should be able to logout" do
    page.html.should =~ /Logged In/
    click_button 'Logout'
    page.current_path.should == '/login'
    click_link 'KaeruEra'
    page.current_path.should == '/login'
  end

  it "should report internal errors" do
    visit('/applications/0/errors')
    click_link 'KaeruEra'
    click_link 'KaeruEraApp'
    cells = all('td').map{|s| s.text}
    cells[0].should =~ /\d+/
    cells[1].should == 'Sequel::NoMatchingRow'
    cells[2].should == 'Sequel::NoMatchingRow' 
    cells[3].should == 'Open'
    cells[4].should =~ /\A#{Date.today}/
  end

  it "should allow viewing most recent errors for application" do
    click_link 'KaeruEraApp'
    cells = all('td').map{|s| s.text}
    cells[0].should == error_id
    cells[1].should == 'RuntimeError'
    cells[2].should =~ /foo/ 
    cells[3].should == 'Open'
    cells[4].should =~ /\A#{Date.today}/
  end

  it "should allow viewing specific error for application" do
    click_link 'KaeruEraApp'
    click_link error_id

    info = all("#content ul li").map{|s| s.text}
    info[0].should == 'User: kaeruera'
    info[1].should == 'Application: KaeruEraApp'
    info[2].should == 'Class: RuntimeError'
    info[3].should =~ /\AMessage:.+foo/
    info[4].should == 'Status: Open'
    info[5].should =~ /\AOccured On:\s+#{Date.today.strftime('%Y\\s+-\\s+%m\\s+-\\s+%d')}/

    bt = all("#content ol li").map{|s| s.text}
    bt[0].should =~ /spec\/web_spec.rb/
    bt[-1].should =~ /<main>|spec/

    tables = all("#content table")
    tables[0].all("td").map{|s| s.text}.should == %w'banana apple'
    tables[1].all("td").map{|s| s.text}.should == %w'pear papaya'
    tables[2].all("td").map{|s| s.text}.should == %w'grapes watermelon'
  end

  it "should have working links on specific error page for searching" do
    click_link 'KaeruEraApp'
    click_link error_id

    click_link 'KaeruEraApp'
    page.html.should =~ /Open Errors for KaeruEraApp/
    click_link error_id

    click_link 'RuntimeError'
    page.html.should =~ /Error Search Results/
    click_link error_id

    (2..8).each do |i|
      all("#content ul li a")[i].click
      page.html.should =~ /Error Search Results/
      click_link error_id
    end

    all("#content ol li a")[0].click
    page.html.should =~ /Error Search Results/
    click_link error_id

    click_link 'grapes'
    page.html.should =~ /Error Search Results/
    click_link error_id

    click_link 'watermelon'
    page.html.should =~ /Error Search Results/
    click_link error_id
    page.html.should =~ /Error #{error_id}/
  end

  it "should allow searching for errors" do
    click_link 'KaeruEraApp'
    click_link error_id
    message = all("#content ul li a")[2].text
    bt = all("#content ol li a")[0].text

    click_link 'Search'
    select 'KaeruEraApp'
    click_button 'Search'
    all('#content tr').size.should == 2

    click_link 'Search'
    select 'KaeruEraApp'
    select 'Closed'
    click_button 'Search'
    all('#content tr').size.should == 0
    page.html.should =~ /No errors matching your search criteria/

    click_link 'Search'
    fill_in 'Error Class', :with=>'RuntimeError'
    click_button 'Search'
    all('#content tr').size.should == 2

    click_link 'Search'
    fill_in 'Error Message Is', :with=>message
    click_button 'Search'
    all('#content tr').size.should == 2

    click_link 'Search'
    fill_in 'Backtrace Includes Line', :with=>bt
    click_button 'Search'
    all('#content tr').size.should == 2

    click_link 'Search'
    fill_in 'Environment Has Key', :with=>'grapes'
    click_button 'Search'
    all('#content tr').size.should == 2

    click_link 'Search'
    fill_in 'Environment Has Key', :with=>'grapes'
    fill_in 'With Value', :with=>'watermelon'
    click_button 'Search'
    all('#content tr').size.should == 2

    click_link 'Search'
    fill_in 'Params Contains', :with=>'banana'
    click_button 'Search'
    all('#content tr').size.should == 2

    click_link 'Search'
    fill_in 'Session Contains', :with=>'papaya'
    click_button 'Search'
    all('#content tr').size.should == 2

    click_link 'Search'
    fill_in 'Occurred On or After', :with=>Date.today
    click_button 'Search'
    all('#content tr').size.should == 2

    click_link 'Search'
    fill_in 'Occurred Before', :with=>Date.today+1
    click_button 'Search'
    all('#content tr').size.should == 2
  end

  it "should allowing updating specific errors" do
    click_link 'KaeruEraApp'
    click_link error_id
    fill_in 'Notes', :with=>'foobar'
    click_button 'Update Error'

    page.html.should =~ /Error Updated/
    page.html.should =~ /Status: Open/
    find('textarea').text.should =~ /foobar/
  end

  it "should closing specific errors" do
    click_link 'KaeruEraApp'
    click_link error_id
    fill_in 'Notes', :with=>'foobar'
    check 'Close Error?'
    click_button 'Update Error'

    page.html.should =~ /Error Updated/
    page.html.should =~ /Status: Closed/
    page.html.should =~ /Error Notes.+foobar/m
  end

  it "should allowing changing passwords" do
    click_link 'Change Password'
    fill_in 'New Password', :with=>'something'
    click_button 'Change Password'
    page.html.should =~ /Password Changed/

    click_button 'Logout'
    login
    page.html.should =~ /No matching email\/password/

    fill_in 'email', :with=>'kaeruera'
    fill_in 'password', :with=>'something'
    click_on 'Login'
    page.html.should =~ /Logged In/
  end

  it "should allowing viewing reporter information for application" do
    click_link 'KaeruEraApp'
    click_link 'Reporter Info'
    page.html.should =~ %r|KaeruEra::Reporter.new\("http://www.example.com(:80)?/report_error", \d+, "[0-9a-f]+"\)|
    page.html.should =~ %r|KaeruEra::AsyncReporter.new\("http://www.example.com(:80)?/report_error", \d+, "[0-9a-f]+"\)|
  end

  it "should allow creating new applications" do
    click_link 'Add Application'
    fill_in 'Application Name', :with=>'FooBar'
    click_button 'Add Application'
    page.html.should =~ /Application Added/
    click_link 'FooBar'
    page.html.should =~ /No open errors for FooBar/
  end
end

describe KaeruEra do
  before do
    a = Application.first
    50.times do |i|
      raise "foo#{i}" rescue a.add_app_error(:error_class=>$!.class,
                        :message=>$!.message,
                        :env=>Sequel.hstore('grapes'=>'watermelon'),
                        :params=>Sequel.pg_json('banana'=>'apple'),
                        :session=>Sequel.pg_json('pear'=>'papaya'),
                        :backtrace=>Sequel.pg_array($!.backtrace))
    end
    login
  end

  it "should have working pagination" do
    click_link 'KaeruEraApp'
    all('#content tbody tr').size.should == 25
    click_link 'Next Page'
    all('#content tbody tr').size.should == 25
    click_link 'Next Page'
    all('#content tbody tr').size.should == 1
    click_link 'Previous Page'
    all('#content tbody tr').size.should == 25
    click_link 'Previous Page'
    all('#content tbody tr').size.should == 25
    click_link 'Next Page'
    all('#content tbody tr').size.should == 25
    click_link 'Next Page'

    click_link error_id
    click_link 'RuntimeError'
    all('#content tbody tr').size.should == 25
    click_link 'Next Page'
    all('#content tbody tr').size.should == 25
    click_link 'Next Page'
    all('#content tbody tr').size.should == 1
    click_link 'Previous Page'
    all('#content tbody tr').size.should == 25
    click_link 'Previous Page'
    all('#content tbody tr').size.should == 25
    click_link 'Next Page'
    all('#content tbody tr').size.should == 25
    click_link 'Next Page'
    all('#content tbody tr').size.should == 1
  end

  it "should be able to view all errors instead of paginating" do
    click_link 'KaeruEraApp'
    all('#content tbody tr').size.should == 25
    click_link 'Show All Open Errors'
    all('#content tbody tr').size.should == 51

    click_link error_id
    click_link 'RuntimeError'
    all('#content tbody tr').size.should == 25
    click_link 'Show All Errors in this Search'
    all('#content tbody tr').size.should == 51
  end

  it "should allow updating multiple errors at once" do
    click_link 'KaeruEraApp'
    all('#content tbody tr').size.should == 25
    fill_in 'Notes', :with=>'foobar'
    click_button 'Update Errors'
    DB[:errors].where(:notes=>'foobar').count.should == 25

    click_link 'KaeruEraApp'
    click_link 'Show All Open Errors'
    fill_in 'Notes', :with=>'foobarbaz'
    click_button 'Update Errors'
    DB[:errors].where(:notes=>'foobarbaz').count.should == 51

    click_link 'KaeruEraApp'
    click_link 'Next Page'
    click_link 'Next Page'
    click_link error_id
    page.html.should =~ /foobarbaz/

    click_link 'RuntimeError'
    click_link 'Show All Errors in this Search'
    fill_in 'Notes', :with=>'foobar'
    check 'Close Errors?'
    click_button 'Update Errors'
    DB[:errors].where(:notes=>'foobar', :closed=>true).count.should == 51

    click_link 'KaeruEraApp'
    page.html.should =~ /No open errors for KaeruEraApp/
  end
end
