Encoding.default_internal = Encoding.default_external = 'UTF-8'
require ::File.expand_path('../kaeruera_app',  __FILE__)
use Rack::CommonLogger unless ENV['RACK_ENV'] == 'development'
run KaeruEra::App.freeze.app

begin
  require 'refrigerator'
rescue LoadError
else
  require 'tilt/sass' unless File.exist?(File.expand_path('../compiled_assets.json', __FILE__))
  Refrigerator.freeze_core(:except=>['BasicObject'])
end
