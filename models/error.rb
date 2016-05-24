# Represents a specific ruby exception raised by an application which
# is reporting errors to KaeruEra.
class Error < Sequel::Model
  many_to_one :application

  dataset_module do
    # Backbone of the web application search form.  Restricts the search
    # to the given user, and further restricts it based on the the hash
    # of params.
    def search(params, user_id)
      ds = where(:user_id=>user_id.to_i)
      ds = where(:application_id=>params[:application].to_i) if params[:application] && !params[:application].empty?
      ds = ds.where(:error_class=>params[:class].to_s) if params[:class] && !params[:class].empty?
      ds = ds.where(:message=>params[:message].to_s) if params[:message] && !params[:message].empty?
      ds = ds.where(:closed=>params[:closed] == '1') if params[:closed] && !params[:closed].empty?
      ds = ds.where(Sequel.pg_array(:backtrace).contains([params[:backtrace].to_s])) if params[:backtrace] && !params[:backtrace].empty?
      if %w'env params session'.include?(type = params[:field]) && !(key = params[:key].to_s).empty?
        param_value = params[:value].to_s
        jsonb = Sequel.pg_jsonb(type.to_sym)

        ds = if param_value.empty?
          ds.where(jsonb.has_key?(key))
        else
          param_value = convert_json_param_value(param_value, params[:field_type])
          ds.where(jsonb.contains(key=>param_value))
        end
      end
      ds = ds.where{created_at >= params[:occurred_after].to_s} if params[:occurred_after] && !params[:occurred_after].empty?
      ds = ds.where{created_at < params[:occurred_before].to_s} if params[:occurred_before] && !params[:occurred_before].empty?
      ds
    end

    # Return dataset in reverse chronological order.
    def most_recent
      reverse_order(:created_at)
    end

    # Return dataset without closed errors.
    def open 
      where(:closed=>false)
    end

    # Return dataset with errors restricted to the given user.
    def with_user(user_id)
      where(:user_id=>user_id)
    end

    private

    def convert_json_param_value(value, type)
      case type
      when 'i'
        value.to_i
      when 'b'
        value == 'true'
      when 'n'
        nil
      else
        value
      end
    end
  end

  # String representing the status of the error (Closed/Open).
  def status
    closed ? 'Closed' : 'Open'
  end

  # An indicator used for the json type, so that the search engine can now
  # how to convert the types.
  def json_type_indicator(value)
    case value
    when Integer
      'i'
    when true, false
      'b'
    when nil
      'n'
    end
  end
end

# Table: errors
# Columns:
#  id             | integer                     | PRIMARY KEY DEFAULT nextval('errors_id_seq'::regclass)
#  user_id        | integer                     | NOT NULL
#  application_id | integer                     |
#  created_at     | timestamp without time zone | NOT NULL DEFAULT now()
#  closed         | boolean                     | DEFAULT false
#  error_class    | text                        | NOT NULL
#  message        | text                        | NOT NULL
#  backtrace      | text[]                      | NOT NULL
#  env            | hstore                      |
#  params         | json                        |
#  session        | json                        |
#  notes          | text                        |
# Indexes:
#  errors_pkey                 | PRIMARY KEY btree (id)
#  errors_application_id_index | btree (application_id)
#  errors_backtrace_index      | gin (backtrace)
#  errors_closed_index         | btree (closed)
#  errors_created_at_index     | btree (created_at)
#  errors_env_index            | gist (env)
#  errors_error_class_index    | btree (error_class)
#  errors_message_index        | btree (message)
#  errors_params_index         | gist (to_tsvector('simple'::regconfig, COALESCE(params::text, ''::text)))
#  errors_session_index        | gist (to_tsvector('simple'::regconfig, COALESCE(session::text, ''::text)))
# Foreign key constraints:
#  errors_application_id_fkey | (application_id) REFERENCES applications(id)
#  errors_user_id_fkey        | (user_id, application_id) REFERENCES applications(user_id, id)
