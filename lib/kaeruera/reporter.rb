require 'rest-client'

module KaeruEra
  class Reporter
    def initialize(host, email, application, token)
      @url = "http://#{host}/report_error"
      @json = {:email=>email, :application=>application, :token=>token}.freeze
    end

    # Opts:
    # :error
    # :params
    # :session
    # :env
    def report(opts={})
      return false unless error = opts[:error] || $!

      h = @json.merge(
        :error_class=>error.class.name,
        :message=>error.message.to_s,
        :backtrace=>error.backtrace
      )

      if v = opts[:params]
        h[:params] = v
      end
      if v = opts[:session]
        h[:session] = v
      end
      if v = opts[:env]
        h[:env] = v
      end

      RestClient.post @url, {:data=>h}, :content_type => :json, :accept => :json
      true
    end
  end
end
