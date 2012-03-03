# -*- encoding: utf-8 -*-
require File.expand_path('../lib/navy/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Andrew Bennett"]
  gem.email         = ["potatosaladx@gmail.com"]
  gem.description   = %q{Ruby daemon inspired by Unicorn.}
  gem.summary       = %q{Ruby daemon inspired by Unicorn.}
  gem.homepage      = "https://github.com/potatosalad/navy"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "navy"
  gem.require_paths = ["lib"]
  gem.version       = Navy::VERSION

  gem.add_development_dependency 'pry'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec', '~> 2.8.0'

  gem.add_dependency 'kgio', '~> 2.6'
end
