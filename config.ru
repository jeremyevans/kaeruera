require ::File.expand_path('../kaeruera_app',  __FILE__)
run KaeruEra::App.freeze.app

require 'tilt/sass' unless File.exist?(File.expand_path('../compiled_assets.json', __FILE__))
Tilt.finalize!

unless ENV['RACK_ENV'] == 'development'
  begin
    require 'refrigerator'
  rescue LoadError
  else
    Refrigerator.freeze_core
  end
end
