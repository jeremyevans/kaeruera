# frozen_string_literal: true
ENV['MT_NO_PLUGINS'] = '1' # Work around stupid autoloading of plugins
gem 'minitest'
require 'minitest/global_expectations/autorun'
require 'minitest/hooks/default'

class Minitest::HooksSpec
  if defined?(TRANSACTIONAL_TESTS)
    around(:all) do |&block|
      KaeruEra::DB.transaction(:rollback=>:always){super(&block)}
    end

    around do |&block|
      KaeruEra::DB.transaction(:rollback=>:always, :savepoint=>true){super(&block)}
    end
  end

  if defined?(Capybara) && defined?(RESET_DRIVER)
    after do
      Capybara.reset_sessions!
      Capybara.use_default_driver
    end
  end
end
