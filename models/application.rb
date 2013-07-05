# Represents an application which will be reporting errors to KaeruEra.
class Application < Sequel::Model
  many_to_one :user
  one_to_many :app_errors, :class=>:Error

  dataset_module do
    # Dataset method restricting application to those with the given user id.
    def with_user(id)
      where(:user_id=>id)
    end
  end
  
  # If a specific token hasn't been set, generate a random token.
  def before_validation
    unless values.has_key?(:token)
      self.token = SecureRandom.hex(20)
    end
    super
  end

  private

  # Set the user_id on the error before saving it.
  def _add_app_error(error)
    error.user_id = user_id
    super
  end
end
