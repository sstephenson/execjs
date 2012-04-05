$:.unshift File.expand_path('../lib', __FILE__)
require 'execjs/version'

Gem::Specification.new do |s|
  s.name    = "execjs"
  s.version = ExecJS::VERSION

  s.homepage    = "https://github.com/sstephenson/execjs"
  s.summary     = "Run JavaScript code from Ruby"
  s.description = <<-EOS
    ExecJS lets you run JavaScript code from Ruby.
  EOS

  s.files = Dir["README.md", "LICENSE", "lib/**/*"]

  s.add_dependency "multi_json", "~>1.0"
  s.add_development_dependency "johnson"#is it possible to make this optional for 1.9? like :platform in Gemfile
  s.add_development_dependency "mustang"
  s.add_development_dependency "rake"
  s.add_development_dependency "therubyracer"
  s.add_development_dependency "therubyrhino"

  s.authors = ["Sam Stephenson", "Josh Peek"]
  s.email   = ["sstephenson@gmail.com", "josh@joshpeek.com"]
end
