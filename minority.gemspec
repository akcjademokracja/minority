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

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  # if spec.respond_to?(:metadata)
  #   spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  # else
  #   raise "RubyGems 2.0 or newer is required to protect against " \
  #     "public gem pushes."
  # end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  #spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.executables << 'identity-puma'
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "puma", "~> 3.9.1"
  spec.add_runtime_dependency "bunny", "~> 2.7.0"
  spec.add_runtime_dependency "freshdesk-ruby", "~> 0.1.0"
  spec.add_runtime_dependency "httparty", "~> 0.14"

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end


