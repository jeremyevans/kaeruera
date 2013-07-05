# Separates access to applications based on specific login information.
class User < Sequel::Model
  one_to_many :applications, :order=>:name

  # Return the id for the user with the given user and password,
  # or nil if there is no matching user.
  def self.login_user_id(email, password)
    return unless email && password
    return unless u = filter(:email=>email).first
    return unless BCrypt::Password.new(u.password_hash) == password
    u.id
  end
  
  # Set the user's password hash to a bcrypt-encrypted one for the given password.
  def password=(new_password)
    self.password_hash = BCrypt::Password.create(new_password, :cost=>BCRYPT_COST)
  end
end
