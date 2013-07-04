class Application < Sequel::Model
  many_to_one :user
  one_to_many :app_errors, :class=>:Error

  dataset_module do
    def with_user(id)
      where(:user_id=>id)
    end
  end
  
  def before_validation
    unless values.has_key?(:token)
      self.token = SecureRandom.hex(20)
    end
    super
  end
end
