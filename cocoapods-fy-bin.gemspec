# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cocoapods-fy-bin/gem_version.rb'

Gem::Specification.new do |spec|
  spec.name          = 'cocoapods-fy-bin'
  spec.version       = CBin::VERSION
  spec.authors       = ['dr']
  spec.email         = ['drwd123@163.com']
  spec.description   = %q{cocoapods-fy-bin is a plugin which helps develpers switching pods between source code and binary.}
  spec.summary       = %q{cocoapods-fy-bin is a plugin which helps develpers switching pods between source code and binary.}
  spec.homepage      = 'https://github.com/dr19900920/cocoapods-fy-bin'
  spec.license       = 'MIT'

  spec.files = Dir["lib/**/*.rb","spec/**/*.rb","lib/**/*.plist"] + %w{README.md LICENSE.txt }

  #spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'parallel'
  spec.add_dependency 'cocoapods'
  spec.add_dependency "cocoapods-generate", '~>2.0.1'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
end
