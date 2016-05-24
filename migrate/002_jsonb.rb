Sequel.migration do
  up do
    alter_table(:errors) do
      drop_index :env, :name=>:errors_env_index, :if_exists=>true
      drop_index :params, :name=>:errors_params_index, :if_exists=>true
      drop_index :session, :name=>:errors_session_index, :if_exists=>true

      set_column_type :env, :jsonb, :using=>Sequel.function(:hstore_to_json_loose, :env).cast(:jsonb)
      set_column_type :params, :jsonb
      set_column_type :session, :jsonb

      add_index :env, :type=>:gin
      add_index :params, :type=>:gin
      add_index :session, :type=>:gin
    end
  end

  down do
    alter_table(:errors) do
      drop_index :env, :name=>:errors_env_index
      drop_index :params, :name=>:errors_params_index
      drop_index :session, :name=>:errors_session_index

      set_column_type :env, :hstore
      set_column_type :params, :json
      set_column_type :session, :json
    end
  end
end
