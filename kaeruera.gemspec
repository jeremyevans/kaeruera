Gem::Specification.new do |s|
  s.name = 'kaeruera'
  s.version = '0.1.0'
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = false
  s.extra_rdoc_files = ["README.rdoc", "CHANGELOG", "MIT-LICENSE"]
  s.rdoc_options += ["--quiet", "--line-numbers", "--inline-source", '--title', 'Reporter Libraries for KaeruEra', '--main', 'README.rdoc']
  s.summary = "Faster SELECTs when using Sequel with pg"
  s.author = "Jeremy Evans"
  s.email = "code@jeremyevans.net"
  s.homepage = "http://github.com/jeremyevans/kaeruera"
  s.required_ruby_version = ">= 1.8.7"
  s.files = %w(MIT-LICENSE CHANGELOG README.rdoc) + Dir["lib/kaeruera/*.rb"]
  s.description = <<END
KaeruEra is a simple error tracking application. This
gem includes 3 separate reporter libaries that can be
used to submit errors to KaeruEra.
END
end
