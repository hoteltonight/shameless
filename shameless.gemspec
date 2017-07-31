lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'shameless/version'

Gem::Specification.new do |spec|
  spec.name          = "shameless"
  spec.version       = Shameless::VERSION
  spec.authors       = ["Olek Janiszewski", "Chas Lemley", "Marek Rosa"]
  spec.email         = ["olek@hoteltonight.com", "chas@hoteltonight.com", "marek@hoteltonight.com"]

  spec.summary       = %q{Scalable distributed append-only data store}
  spec.homepage      = "https://github.com/hoteltonight/shameless"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "msgpack"
  spec.add_dependency "sequel", "~> 4.0"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "sqlite3"
end
