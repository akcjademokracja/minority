# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'minority/version'

Gem::Specification.new do |spec|
  spec.name          = "minority"
  spec.version       = Minority::VERSION
  spec.authors       = ["Marcin Koziej"]
  spec.email         = ["marcin@akcjademokracja.pl"]

  spec.summary       = %q{Minority is a gem adding extra functionalities to Identity.}
  spec.description   = %q{
Minority is a gem adding extra functionalities to Identity.
They could hopefully become mainstream one day. Before this happens, though, they stay here.
}
  spec.homepage      = "https://github.com/akcjademokracja/minority"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  #spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "bunny", "~> 2.7.0"
  spec.add_runtime_dependency "httparty", "~> 0.14"
  spec.add_runtime_dependency "unicode", "~> 0.4.4"
  spec.add_runtime_dependency "babosa", "~> 1.0.2"

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"

  spec.post_install_message = "Minority at: #{`git rev-parse --short HEAD`.strip}"
end


