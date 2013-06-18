Sequel.migration do
  change do
    create_table(:users) do
      primary_key :id
      String :email, :null=>false, :unique=>true
      String :password_hash, :null=>false
    end

    create_table(:applications) do
      primary_key :id
      foreign_key :user_id, :users, :null=>false
      String :name, :null=>false
      String :token, :null=>false
      unique [:user_id, :name]
    end

    create_table(:errors) do
      primary_key :id
      foreign_key :application_id, :applications, :null=>false, :index=>true
      Time :created_at, :null=>false, :default=>Sequel::CURRENT_TIMESTAMP, :index=>true
      TrueClass :closed, :default=>false, :index=>true
      String :error_class, :null=>false, :index=>true
      String :message, :null=>false, :index=>{:type=>:full_text, :index_type=>:gist}
      column :backtrace , 'text[]', :null=>false, :index=>{:type=>:gin}
      hstore :env, :index=>{:type=>:gist}
      json :params
      json :session
      String :notes

      full_text_index Sequel.cast(:params, String), :index_type=>:gist, :name=>:errors_params_index
      full_text_index Sequel.cast(:session, String), :index_type=>:gist, :name=>:errors_session_index
    end
  end
end
