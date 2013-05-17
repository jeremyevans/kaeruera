class Application < Sequel::Model
  many_to_one :user
  one_to_many :app_errors, :class=>:Error
  
  def before_validation
    unless values.has_key?(:token)
      self.token = SecureRandom.hex(20)
    end
  end
end
