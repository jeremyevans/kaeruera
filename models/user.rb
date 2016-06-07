module KaeruEra
# Separates access to applications based on specific login information.
class User < Sequel::Model(DB)
  one_to_many :applications, :order=>:name

  # Set the user's password hash to a bcrypt-encrypted one for the given password.
  def password=(new_password)
    self.password_hash = BCrypt::Password.create(new_password, :cost=>BCRYPT_COST)
  end
end
end

# Table: users
# Columns:
#  id            | integer | PRIMARY KEY DEFAULT nextval('users_id_seq'::regclass)
#  email         | text    | NOT NULL
#  password_hash | text    | NOT NULL
# Indexes:
#  users_pkey      | PRIMARY KEY btree (id)
#  users_email_key | UNIQUE btree (email)
# Referenced By:
#  applications | applications_user_id_fkey | (user_id) REFERENCES users(id)
