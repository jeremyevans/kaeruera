require 'sequel'

module KaeruEra
  class Recorder
    class Error < StandardError; end

    def initialize(uri, email, application)
      @db = uri.is_a?(Sequel::Database) ? uri : Sequel.connect(uri, :keep_reference=>false)
      @db.extension :pg_array, :pg_hstore, :pg_json
      raise(Error, "No matching application in database for #{email}/#{application}") unless @application_id = @db[:applications].where(:user_id=>@db[:users].where(:email=>email).get(:id), :name=>application).get(:id)
    end

    # Opts:
    # :error
    # :params
    # :session
    # :env
    def record(opts={})
      return false unless error = opts[:error] || $!

      h = {
        :application_id=>@application_id,
        :error_class=>error.class.name,
        :message=>error.message.to_s,
        :backtrace=>Sequel.pg_array(error.backtrace)
      }

      if v = opts[:params]
        h[:params] = Sequel.pg_json(v)
      end
      if v = opts[:session]
        h[:session] = Sequel.pg_json(v)
      end
      if v = opts[:env]
        h[:env] = Sequel.hstore(v)
      end

      @db[:errors].insert(h)
    rescue => e
      e
    end
  end
end
