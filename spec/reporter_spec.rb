# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'
ENV['KAERUERA_SESSION_SECRET'] ||= '1'*64
ENV['MULTITHREADED_TRANSACTIONAL_TEST'] = '1'

require_relative '../db'
require_relative 'coverage_helper'
require_relative '../lib/kaeruera/reporter'
require_relative '../lib/kaeruera/async_reporter'

include KaeruEra

require_relative 'spec_helper'
require_relative 'shared_lib_spec'
require_relative 'model_freeze'

require 'puma/cli'
require 'nio'

port = 25578
queue = Queue.new
server = Puma::CLI.new(['-s', '-b', "tcp://127.0.0.1:#{port}", '-t', '1:1', 'config.ru'])
server.launcher.events.on_booted{queue.push(nil)}
Thread.new do
  server.launcher.run
end
queue.pop

class Minitest::HooksSpec
  remove_method(:around)
  around do |&block|
    KaeruEra::DB.transaction(:rollback=>:always, :savepoint=>true, :auto_savepoint=>true) do |c|
      KaeruEra::DB.temporarily_release_connection(c) do
        super(&block)
      end
    end
  end

  before(:all) do
    user_id = KaeruEra::DB[:users].insert(:email=>'ke', :password_hash=>'secret')
    @application_id = KaeruEra::DB[:applications].insert(:user_id=>user_id, :name=>'app', :token=>'1')
  end
end

describe KaeruEra::Reporter do
  before(:all) do
    @reporter = KaeruEra::Reporter.new("http://127.0.0.1:#{port}/report_error", @application_id, '1')
  end

  include KaeruEraLibs
end

describe KaeruEra::AsyncReporter do
  before(:all) do
    @reporter = KaeruEra::AsyncReporter.new("http://127.0.0.1:#{port}/report_error", @application_id, '1')
    def @reporter.report(opts={})
      if (r = super) == true
        t = Time.now
        while sleep 0.01
          if id = KaeruEra::DB[:errors].max(:id)
            return id
          end
          if Time.now - t > 2
            return nil
          end
        end
      else
        r
      end
    end
    @skip_exception_test = true
  end

  include KaeruEraLibs
end
