gem 'minitest'
require 'minitest/autorun'
require 'minitest/hooks/default'

class Minitest::HooksSpec
  if defined?(TRANSACTIONAL_TESTS)
    def around_all
      DB.transaction(:rollback=>:always){yield}
    end

    def around
      DB.transaction(:rollback=>:always, :savepoint=>true){yield}
    end
  end

  if defined?(Capybara) && defined?(RESET_DRIVER)
    after do
      Capybara.reset_sessions!
      Capybara.use_default_driver
    end
  end
end
