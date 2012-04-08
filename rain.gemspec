# -*- encoding: utf-8 -*-
require File.expand_path('../lib/rain/version', __FILE__)

Gem::Specification.new do |s|
  s.authors       = ["Vaughn Draughon"]
  s.email         = ["vaughn@rocksolidwebdesign.com"]
  s.license     = "BSD"
  s.summary       = %q{TODO: Ruby Artificial Intelligence and Neural Network library}
  s.description   = %q{TODO: A ruby library for commonly desired utilities in the artificial intelligence and machine learning world such as discretizers/discretization and learning classification systems such as genetic algorithms and neural networks}
  s.homepage      = ""

  s.files         = `git ls-files`.split($\)
  s.executables   = s.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.name          = "rain"
  s.require_paths = ["lib"]
  s.version       = Rain::VERSION

  s.add_development_dependency "bundler", ">= 1.0.0"
  s.add_development_dependency "rspec", "~> 2.3"
  s.add_development_dependency "sqlite3"
  s.add_development_dependency "activerecord", ">= 3.2"
end
