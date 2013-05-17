class User < Sequel::Model
  one_to_many :applications, :order=>:name

  def self.login_user_id(email, password)
    return unless email && password
    return unless u = filter(:email=>email).first
    return unless BCrypt::Password.new(u.password_hash) == password
    u.id
  end
  
  def password=(new_password)
    self.password_hash = BCrypt::Password.create(new_password, :cost=>BCRYPT_COST)
  end
end
