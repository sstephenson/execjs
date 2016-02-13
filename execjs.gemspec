$:.unshift File.expand_path('../lib', __FILE__)
require 'execjs/version'

Gem::Specification.new do |s|
  s.name    = "execjs"
  s.version = ExecJS::VERSION

  s.homepage    = "https://github.com/rails/execjs"
  s.summary     = "Run JavaScript code from Ruby"
  s.description = "ExecJS lets you run JavaScript code from Ruby."

  s.files = Dir["README.md", "MIT-LICENSE", "lib/**/*"]

  s.add_development_dependency "rake"

  s.licenses = ['MIT']

  s.authors = ["Sam Stephenson", "Josh Peek"]
  s.email   = ["sstephenson@gmail.com", "josh@joshpeek.com"]

  # We only support MRI 2+ but this is needed to work with JRuby 1.7.
  s.required_ruby_version = '>= 1.9.3'
end
