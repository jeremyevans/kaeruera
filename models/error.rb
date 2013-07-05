# Represents a specific ruby exception raised by an application which
# is reporting errors to KaeruEra.
class Error < Sequel::Model
  many_to_one :application

  dataset_module do
    # Backbone of the web application search form.  Restricts the search
    # to the given user, and further restricts it based on the the hash
    # of params.
    def search(params, user_id)
      app_ds = Application.with_user(user_id).select(:id)
      app_ds = app_ds.where(:id=>params[:application].to_i) if params[:application] && !params[:application].empty?
      ds = where(:application_id=>app_ds)
      ds = ds.where(:error_class=>params[:class].to_s) if params[:class] && !params[:class].empty?
      ds = ds.where(:message=>params[:message].to_s) if params[:message] && !params[:message].empty?
      ds = ds.where(:closed=>params[:closed] == '1') if params[:closed] && !params[:closed].empty?
      ds = ds.where(Sequel.pg_array(:backtrace).contains([params[:backtrace].to_s])) if params[:backtrace] && !params[:backtrace].empty?
      if params[:env_key] && !params[:env_key].empty?
        ds = if params[:env_value] && !params[:env_value].empty?
          ds.where(Sequel.hstore(:env).contains(params[:env_key].to_s=>params[:env_value].to_s))
        else
          ds.where(Sequel.hstore(:env).has_key?(params[:env_key].to_s))
        end
      end
      ds = ds.full_text_search(Sequel.cast(:params, String), params[:params].to_s) if params[:params] && !params[:params].empty?
      ds = ds.full_text_search(Sequel.cast(:session, String), params[:session].to_s) if params[:session] && !params[:session].empty?
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
      where(:application_id=>Application.where(:user_id=>user_id).select(:id))
    end
  end

  # String representing the status of the error (Closed/Open).
  def status
    closed ? 'Closed' : 'Open'
  end
end
