require 'sequel'

module KaeruEra
  # Reporter class that inserts the error information directly
  # into the database instead of reporting it to a web server via
  # HTTP.
  class DatabaseReporter
    # Exception raised when no matching application is found in the
    # database (i.e. not matching email and application).
    class Error < StandardError; end

    # Arguments:
    # uri :: Either a Sequel::Database instance or a String treated as a URI.
    #        If a Sequel::Database instance is given, uses given database,
    #        otherwise, connects to the database specified by the URI via Sequel.
    # email :: The KaeruEra email/login for the application.
    # application :: The KaeruEra application name
    def initialize(uri, email, application)
      @db = uri.is_a?(Sequel::Database) ? uri : Sequel.connect(uri, :keep_reference=>false)
      @db.extension :pg_array, :pg_hstore, :pg_json
      @application_id, @user_id = @db[:applications].where(:user_id=>@db[:users].where(:email=>email).get(:id), :name=>application).get([:id, :user_id])
      raise(Error, "No matching application in database for #{email}/#{application}") unless @application_id
    end

    # If an error cannot be determined, returns false.
    # Otherwise, inserts the error directly into the
    # database.
    # If an exception would be raised by this code, returns
    # the exception instead of raising it.
    #
    # Supports the same options as Reporter#report.
    def report(opts={})
      return false unless error = opts[:error] || $!

      h = {
        :user_id=>@user_id,
        :application_id=>@application_id,
        :error_class=>error.class.name,
        :message=>error.message.to_s,
        :backtrace=>Sequel.pg_array(error.backtrace)
      }

      if v = opts[:params]
        h[:params] = Sequel.pg_json(v.to_hash)
      end
      if v = opts[:session]
        h[:session] = Sequel.pg_json(v.to_hash)
      end
      if v = opts[:env]
        h[:env] = Sequel.hstore(v.to_hash)
      end

      @db[:errors].insert(h)
    rescue => e
      e
    end
  end
end
