Sequel.migration do
  up do
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
      foreign_key :application_id, :applications, :null=>false
      Time :created_at, :null=>false, :default=>Sequel::CURRENT_TIMESTAMP
      TrueClass :closed, :default=>false
      String :error_class, :null=>false
      String :message, :null=>false
      column :backtrace , 'text[]', :null=>false
      hstore :env 
      json :params
      json :session
      String :search_text

      full_text_index :search_text
    end
    create_function(:populate_search_text, <<-SQL, :returns=>:trigger, :language=>:plpgsql)
      BEGIN
        NEW.search_text = #{DB.literal Sequel.join([:error_class, :message, :backtrace, :env, :params, :session].map{|c| Sequel.function(:coalesce, Sequel.cast(Sequel.qualify(Sequel.lit('NEW'), c), String), '')}, ' ')};
        RETURN NEW;
      END;
    SQL

    create_trigger(:errors, :populate_search_text, :populate_search_text, :events=>[:insert, :update], :each_row=>true)
  end
  down do
    drop_function(:populate_search_text)
    drop_table(:errors, :applications, :users)
  end
end
