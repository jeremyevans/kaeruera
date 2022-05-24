ENV['RACK_ENV'] = 'test'
require 'capybara'
require 'capybara/dsl'
require 'capybara/optionally_validate_html5'
require 'rack/test'

TRANSACTIONAL_TESTS = true
RESET_DRIVER = true
require_relative 'spec_helper'
require_relative '../models'

[:errors, :applications, :users].each{|t| KaeruEra::DB[t].delete}
raise 'foo' rescue KaeruEra::User.create(:email=>'kaeruera', :password=>'secret').
  add_application(:name=>'KaeruEraApp').
  add_app_error(:error_class=>$!.class,
                :message=>$!.message,
                :env=>Sequel.pg_jsonb('grapes'=>'watermelon'),
                :params=>Sequel.pg_jsonb('banana'=>123),
                :session=>Sequel.pg_jsonb('pear'=>nil),
                :backtrace=>Sequel.pg_array($!.backtrace))
error_id = KaeruEra::DB[:errors].max(:id).to_s

Gem.suffix_pattern

require_relative '../kaeruera_app'

begin
  require 'refrigerator'
rescue LoadError
else
  Refrigerator.freeze_core(:except=>['BasicObject'])
end

Capybara.app = KaeruEra::App.freeze.app
Capybara.exact = true

class Minitest::Spec
  include Rack::Test::Methods
  include Capybara::DSL

  def all(*a)
    page.all(*a)
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
    page.html.must_match(/no matching login/)
    fill_in 'email', :with=>'kaeruera'
    fill_in 'password', :with=>'secet'
    click_on 'Login'
    page.html.must_match(/invalid password/)
  end
end

describe KaeruEra do
  before do
    login
  end

  it "should be able to logout" do
    page.html.must_match(/You have been logged in/)
    click_button 'Logout'
    page.current_path.must_equal '/login'
    click_link 'KaeruEra'
    page.current_path.must_equal '/login'
  end

  it "should report internal errors" do
    visit('/applications/0/errors')
    click_link 'KaeruEra'
    click_link 'KaeruEraApp'
    cells = all('td').map{|s| s.text}
    cells[0].must_match(/\d+/)
    cells[1].must_equal 'Sequel::NoMatchingRow'
    cells[2].must_equal 'Sequel::NoMatchingRow' 
    cells[3].must_equal 'Open'
    cells[4].must_match(/\A#{Date.today}/)
  end

  it "should allow viewing most recent errors for application" do
    click_link 'KaeruEraApp'
    cells = all('td').map{|s| s.text}
    cells[0].must_equal error_id
    cells[1].must_equal 'RuntimeError'
    cells[2].must_match(/foo/) 
    cells[3].must_equal 'Open'
    cells[4].must_match(/\A#{Date.today}/)
  end

  it "should allow viewing specific error for application" do
    click_link 'KaeruEraApp'
    click_link error_id

    info = all("#content ul li").map{|s| s.text}
    info[0].must_equal 'User: kaeruera'
    info[1].must_equal 'Application: KaeruEraApp'
    info[2].must_equal 'Class: RuntimeError'
    info[3].must_match(/\AMessage:.+foo/)
    info[4].must_equal 'Status: Open'
    info[5].must_match(/\AOccured On:\s+\d+\s+-\s+\d+\s+-\s+\d+\s+T\s+\d+\s+:\s+\d+\s+:\s+\d+/)

    bt = all("#content ol li").map{|s| s.text}
    bt[0].must_match(/spec\/web_spec.rb/)
    bt[-1].must_match(/<main>|spec/)

    tables = all("#content table")
    tables[0].all("td").map{|s| s.text}.must_equal %w'banana 123'
    tables[1].all("td").map{|s| s.text}.must_equal %w'pear (null)'
    tables[2].all("td").map{|s| s.text}.must_equal %w'grapes watermelon'
  end

  it "should have working links on specific error page for searching" do
    click_link 'KaeruEraApp'
    click_link error_id

    click_link 'KaeruEraApp'
    page.html.must_match(/Open Errors for KaeruEraApp/)
    click_link error_id

    click_link 'RuntimeError'
    page.html.must_match(/Error Search Results/)
    click_link error_id

    (2..8).each do |i|
      all("#content ul li a")[i].click
      page.html.must_match(/Error Search Results/)
      click_link error_id
    end

    all("#content ol li a")[0].click
    page.html.must_match(/Error Search Results/)
    click_link error_id

    click_link 'grapes'
    page.html.must_match(/Error Search Results/)
    click_link error_id

    click_link 'watermelon'
    page.html.must_match(/Error Search Results/)
    click_link error_id
    page.html.must_match(/Error #{error_id}/)
  end

  it "should allow searching for errors" do
    click_link 'KaeruEraApp'
    click_link error_id
    message = all("#content ul li a")[2].text
    bt = all("#content ol li a")[0].text

    click_link 'Search'
    select 'KaeruEraApp'
    click_button 'Search'
    all('#content tr').size.must_equal 2

    click_link 'Search'
    select 'KaeruEraApp'
    select 'Closed'
    click_button 'Search'
    all('#content tr').size.must_equal 0
    page.html.must_match(/No errors matching your search criteria/)

    click_link 'Search'
    fill_in 'Error Class', :with=>'RuntimeError'
    click_button 'Search'
    all('#content tr').size.must_equal 2

    click_link 'Search'
    fill_in 'Error Message Is', :with=>message
    click_button 'Search'
    all('#content tr').size.must_equal 2

    click_link 'Search'
    fill_in 'Backtrace Includes Line', :with=>bt
    click_button 'Search'
    all('#content tr').size.must_equal 2

    click_link 'Search'
    select 'env'
    fill_in 'JSON Field Key', :with=>'grapes'
    click_button 'Search'
    all('#content tr').size.must_equal 2

    click_link 'Search'
    select 'env'
    fill_in 'JSON Field Key', :with=>'grapes'
    fill_in 'JSON Field Value', :with=>'watermelon'
    click_button 'Search'
    all('#content tr').size.must_equal 2

    click_link 'Search'
    select 'params'
    fill_in 'JSON Field Key', :with=>'banana'
    click_button 'Search'
    all('#content tr').size.must_equal 2

    click_link 'Search'
    select 'params'
    fill_in 'JSON Field Key', :with=>'banana'
    fill_in 'JSON Field Value', :with=>'123'
    click_button 'Search'
    all('#content tr').size.must_equal 0

    click_link 'Search'
    select 'params'
    fill_in 'JSON Field Key', :with=>'banana'
    fill_in 'JSON Field Value', :with=>'123'
    select 'Integer'
    click_button 'Search'
    all('#content tr').size.must_equal 2

    click_link 'Search'
    select 'session'
    fill_in 'JSON Field Key', :with=>'pear'
    click_button 'Search'
    all('#content tr').size.must_equal 2

    click_link 'Search'
    select 'session'
    fill_in 'JSON Field Key', :with=>'pear'
    fill_in 'JSON Field Value', :with=>' '
    select 'Null'
    click_button 'Search'
    all('#content tr').size.must_equal 2

    click_link 'Search'
    fill_in 'Occurred On or After', :with=>Date.today
    click_button 'Search'
    all('#content tr').size.must_equal 2

    click_link 'Search'
    fill_in 'Occurred Before', :with=>Date.today+1
    click_button 'Search'
    all('#content tr').size.must_equal 2
  end

  it "should allowing updating specific errors" do
    click_link 'KaeruEraApp'
    click_link error_id
    fill_in 'Notes', :with=>'foobar'
    click_button 'Update Error'

    page.html.must_match(/Error Updated/)
    page.html.must_match(/Status: Open/)
    find('textarea').text.must_match(/foobar/)
  end

  it "should closing specific errors" do
    click_link 'KaeruEraApp'
    click_link error_id
    fill_in 'Notes', :with=>'foobar'
    check 'Close Error?'
    click_button 'Update Error'

    page.html.must_match(/Error Updated/)
    page.html.must_match(/Status: Closed/)
    page.html.must_match(/Error Notes.+foobar/m)
  end

  it "should allowing changing passwords" do
    click_link 'Change Password'
    fill_in 'Password', :with=>'secret'
    fill_in 'New Password', :with=>'something'
    fill_in 'Confirm Password', :with=>'something'
    click_button 'Change Password'
    page.html.must_match(/Your password has been changed/)

    click_button 'Logout'
    login
    page.html.must_match(/invalid password/)

    fill_in 'email', :with=>'kaeruera'
    fill_in 'password', :with=>'something'
    click_on 'Login'
    page.html.must_match(/You have been logged in/)
  end

  it "should allowing viewing reporter information for application" do
    click_link 'KaeruEraApp'
    click_link 'Reporter Info'
    page.html.must_match %r|KaeruEra::Reporter.new\('http://www.example.com(:80)?/report_error', \d+, '[0-9a-f]+'\)|
    page.html.must_match %r|KaeruEra::AsyncReporter.new\('http://www.example.com(:80)?/report_error', \d+, '[0-9a-f]+'\)|
  end

  it "should allow creating new applications" do
    click_link 'Add Application'
    fill_in 'Application Name*', :with=>'FooBar'
    click_button 'Add Application'
    page.html.must_match(/Application Added/)
    click_link 'FooBar'
    page.html.must_match(/No open errors for FooBar/)
  end
end

describe KaeruEra do
  before(:all) do
    a = KaeruEra::Application.first
    50.times do |i|
      raise "foo#{i}" rescue a.add_app_error(:error_class=>$!.class,
                        :message=>$!.message,
                        :env=>Sequel.pg_jsonb('grapes'=>'watermelon'),
                        :params=>Sequel.pg_jsonb('banana'=>'apple'),
                        :session=>Sequel.pg_jsonb('pear'=>'papaya'),
                        :backtrace=>Sequel.pg_array($!.backtrace))
    end
  end
  before do
    login
  end

  it "should have working pagination" do
    click_link 'KaeruEraApp'
    all('#content tbody tr').size.must_equal 25
    click_link 'Next Page'
    all('#content tbody tr').size.must_equal 25
    click_link 'Next Page'
    all('#content tbody tr').size.must_equal 1
    click_link 'Previous Page'
    all('#content tbody tr').size.must_equal 25
    click_link 'Previous Page'
    all('#content tbody tr').size.must_equal 25
    click_link 'Next Page'
    all('#content tbody tr').size.must_equal 25
    click_link 'Next Page'

    click_link error_id
    click_link 'RuntimeError'
    all('#content tbody tr').size.must_equal 25
    click_link 'Next Page'
    all('#content tbody tr').size.must_equal 25
    click_link 'Next Page'
    all('#content tbody tr').size.must_equal 1
    click_link 'Previous Page'
    all('#content tbody tr').size.must_equal 25
    click_link 'Previous Page'
    all('#content tbody tr').size.must_equal 25
    click_link 'Next Page'
    all('#content tbody tr').size.must_equal 25
    click_link 'Next Page'
    all('#content tbody tr').size.must_equal 1
  end

  it "should be able to view all errors instead of paginating" do
    click_link 'KaeruEraApp'
    all('#content tbody tr').size.must_equal 25
    click_link 'Show All Open Errors'
    all('#content tbody tr').size.must_equal 51

    click_link error_id
    click_link 'RuntimeError'
    all('#content tbody tr').size.must_equal 25
    click_link 'Show All Errors in this Search'
    all('#content tbody tr').size.must_equal 51
  end

  it "should allow updating multiple errors at once" do
    click_link 'KaeruEraApp'
    all('#content tbody tr').size.must_equal 25
    fill_in 'Notes', :with=>'foobar'
    click_button 'Update Errors'
    KaeruEra::DB[:errors].where(:notes=>'foobar').count.must_equal 25

    click_link 'KaeruEraApp'
    click_link 'Show All Open Errors'
    fill_in 'Notes', :with=>'foobarbaz'
    click_button 'Update Errors'
    KaeruEra::DB[:errors].where(:notes=>'foobarbaz').count.must_equal 51

    click_link 'KaeruEraApp'
    click_link 'Next Page'
    click_link 'Next Page'
    click_link error_id
    page.html.must_match(/foobarbaz/)

    click_link 'RuntimeError'
    click_link 'Show All Errors in this Search'
    fill_in 'Notes', :with=>'foobar'
    check 'Close Errors?'
    click_button 'Update Errors'
    KaeruEra::DB[:errors].where(:notes=>'foobar', :closed=>true).count.must_equal 51

    click_link 'KaeruEraApp'
    page.html.must_match(/No open errors for KaeruEraApp/)
  end
end
