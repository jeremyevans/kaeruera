# Separates access to applications based on specific login information.
class User < Sequel::Model
  one_to_many :applications, :order=>:name

  # Set the user's password hash to a bcrypt-encrypted one for the given password.
  def password=(new_password)
    self.password_hash = BCrypt::Password.create(new_password, :cost=>BCRYPT_COST)
  end
end
