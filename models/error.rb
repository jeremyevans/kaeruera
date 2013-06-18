class Error < Sequel::Model
  many_to_one :application

  dataset_module do
    def search(params, user_id)
      app_ds = Application.where(:user_id=>user_id).select(:id)
      app_ds = app_ds.where(:id=>params[:application].to_i) if params[:application] && !params[:application].empty?
      ds = where(:application_id=>app_ds)
      ds = ds.where(:error_class=>params[:class].to_s) if params[:class] && !params[:class].empty?
      ds = ds.full_text_search(:message, params[:message].to_s) if params[:message] && !params[:message].empty?
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
      ds
    end
    def most_recent(limit)
      reverse_order(:created_at).limit(limit)
    end
  end

  def status
    closed ? 'Closed' : 'Open'
  end
end
