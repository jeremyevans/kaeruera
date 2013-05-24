require 'rest-client'
require 'json'

module KaeruEra
  class Reporter
    def initialize(url, application_id, token)
      @url = url
      @application_id = application_id
      @token = token
    end

    # Opts:
    # :error
    # :params
    # :session
    # :env
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
    end
  end
end
