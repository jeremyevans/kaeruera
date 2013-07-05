require 'kaeruera/reporter'
require 'thread'

module KaeruEra
  class AsyncReporter
    def initialize(url, application_id, token)
      reporter = Reporter.new(url, application_id, token)
      @queue = Queue.new
      Thread.new do
        loop{reporter.report(@queue.pop) rescue nil}
      end
    end

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
