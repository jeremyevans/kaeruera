module KaeruEra
# Represents a specific ruby exception raised by an application which
# is reporting errors to KaeruEra.
class Error < Model
  many_to_one :application

  dataset_module do
    # Backbone of the web application search form.  Restricts the search
    # to the given user, and further restricts it based on the the hash
    # of search_opts.
    def search(search_opts, user_id)
      ds = where(:user_id=>user_id)
      ds = where(:application_id=>search_opts[:application]) if search_opts[:application]
      ds = ds.where(:error_class=>search_opts[:class]) if search_opts[:class]
      ds = ds.where(:message=>search_opts[:message]) if search_opts[:message]
      ds = ds.where(:closed=>search_opts[:closed]) unless search_opts[:closed].nil?
      ds = ds.where(Sequel.pg_array(:backtrace).contains([search_opts[:backtrace]])) if search_opts[:backtrace]
      if %w'env params session'.include?(type = search_opts[:field]) && (key = search_opts[:key])
        jsonb = Sequel.pg_jsonb(type.to_sym)

        ds = if param_value = search_opts[:value]
          param_value = convert_json_param_value(param_value, search_opts[:field_type])
          ds.where(jsonb.contains(key=>param_value))
        else
          ds.where(jsonb.has_key?(key))
        end
      end
      ds = ds.where{created_at >= search_opts[:occurred_after]} if search_opts[:occurred_after]
      ds = ds.where{created_at < search_opts[:occurred_before]} if search_opts[:occurred_before]
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
#  env            | jsonb                       |
#  params         | jsonb                       |
#  session        | jsonb                       |
#  notes          | text                        |
# Indexes:
#  errors_pkey                 | PRIMARY KEY btree (id)
#  errors_application_id_index | btree (application_id)
#  errors_backtrace_index      | gin (backtrace)
#  errors_closed_index         | btree (closed)
#  errors_created_at_index     | btree (created_at)
#  errors_env_index            | gin (env)
#  errors_error_class_index    | btree (error_class)
#  errors_message_index        | btree (message)
#  errors_params_index         | gin (params)
#  errors_session_index        | gin (session)
# Foreign key constraints:
#  errors_application_id_fkey | (application_id) REFERENCES applications(id)
#  errors_user_id_fkey        | (user_id, application_id) REFERENCES applications(user_id, id)
