# frozen_string_literal: true
module KaeruEra
# Represents an application which will be reporting errors to KaeruEra.
class Application < Model
  many_to_one :user
  one_to_many :app_errors, :class=>"KaeruEra::Error"

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

  def validate
    validates_presence(:name)
    super
  end

  private

  # Set the user_id on the error before saving it.
  def _add_app_error(error)
    error.user_id = user_id
    super
  end
end
end

# Table: applications
# Columns:
#  id      | integer | PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY
#  user_id | integer | NOT NULL
#  name    | text    | NOT NULL
#  token   | text    | NOT NULL
# Indexes:
#  applications_pkey             | PRIMARY KEY btree (id)
#  applications_user_id_id_key   | UNIQUE btree (user_id, id)
#  applications_user_id_name_key | UNIQUE btree (user_id, name)
# Foreign key constraints:
#  applications_user_id_fkey | (user_id) REFERENCES users(id)
# Referenced By:
#  errors | errors_application_id_fkey | (application_id) REFERENCES applications(id)
#  errors | errors_user_id_fkey        | (user_id, application_id) REFERENCES applications(user_id, id)
