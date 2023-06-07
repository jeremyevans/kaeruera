# frozen_string_literal: true
require_relative 'reporter'
require 'thread'

module KaeruEra
  # AsyncReporter reports the error to a KaeruEra
  # application via HTTP, but does it asynchronously.
  class AsyncReporter
    # Accepts the same arguments as Reporter.
    def initialize(url, application_id, token)
      reporter = Reporter.new(url, application_id, token)
      @queue = Queue.new
      Thread.new do
        loop{reporter.report(@queue.pop) rescue nil}
      end
    end

    # If an error cannot be determined, returns false.
    # Otherwise, adds the error to the queue of errors
    # to handle asynchronously and returns true.  If
    # an exception would be raised by this code, returns
    # the exception instead of raising it.
    #
    # Supports the same options as Reporter#report.
    def report(opts={})
      unless opts[:error]
        return false unless $!
        opts = opts.merge(:error=>$!)
      end
      @queue.push(opts)
      true
    rescue => e
      e
    end
  end
end
