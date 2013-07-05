require 'rest-client'
require 'json'

module KaeruEra
  # The standard Reporter class reports errors via HTTP requests
  # to a KaeruEra web server.
  class Reporter
    # Arguments:
    # url :: The url to use to report the error.
    # application_id :: The id for the application on the KaeruEra server.
    # token :: The application's token on the KaeruEra server.
    #
    # You can get this information from looking at the "Reporter Info"
    # page on the KaeruEra server.
    def initialize(url, application_id, token)
      @url = url
      @application_id = application_id
      @token = token
    end

    # If an error cannot be determined, returns false.
    # Otherwise, reports the error to the KaeruEra server via HTTP.
    # If an exception would be raised by this code, returns
    # the exception instead of raising it.
    #
    # Options:
    # :error :: The exception to report
    # :env :: The environment variables related to this exception.
    #         For a web application, generally the HTTP request
    #         environment variables.
    # :params :: The params related to the exception.  For a web
    #            application, generally the GET/POST parameters.
    # :session :: Any session information to the exception.
    def report(opts={})
      return false unless error = opts[:error] || $!

      h = {
        :error_class=>error.class.name,
        :message=>error.message.to_s,
        :backtrace=>error.backtrace
      }

      if v = opts[:params]
        h[:params] = v
      end
      if v = opts[:session]
        h[:session] = v
      end
      if v = opts[:env]
        h[:env] = v
      end

      res = RestClient.post @url, {:data=>h, :id=>@application_id, :token=>@token}.to_json, :content_type => :json, :accept => :json
      JSON.parse(res)['error_id']
    rescue => e
      e
    end
  end
end
