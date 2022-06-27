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
      unique [:user_id, :id]
    end

    create_table(:errors) do
      primary_key :id
      Integer :user_id, :null=>false
      foreign_key :application_id, :applications, :index=>true
      Time :created_at, :null=>false, :default=>Sequel::CURRENT_TIMESTAMP, :index=>true
      TrueClass :closed, :default=>false, :index=>true
      String :error_class, :null=>false, :index=>true
      String :message, :null=>false, :index=>true
      column :backtrace , 'text[]', :null=>false, :index=>{:type=>:gin}
      jsonb :env, :index=>{:type=>:gin}
      jsonb :params, :index=>{:type=>:gin}
      jsonb :session, :index=>{:type=>:gin}

      String :notes

      foreign_key [:user_id, :application_id], :applications, :key=>[:user_id, :id]
    end
  end
end
