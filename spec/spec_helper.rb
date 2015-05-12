gem 'minitest'
require 'minitest/autorun'
require 'minitest/hooks/default'

class Minitest::HooksSpec
  if defined?(TRANSACTIONAL_TESTS)
    around(:all) do |&block|
      DB.transaction(:rollback=>:always){super(&block)}
    end

    around do |&block|
      DB.transaction(:rollback=>:always, :savepoint=>true){super(&block)}
    end
  end

  if defined?(Capybara) && defined?(RESET_DRIVER)
    after do
      Capybara.reset_sessions!
      Capybara.use_default_driver
    end
  end
end
