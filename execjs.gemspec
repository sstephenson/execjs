$:.unshift File.expand_path('..', __FILE__)
require 'execjs/version'

Gem::Specification.new do |s|
  s.name    = "execjs"
  s.version = ExecJS::VERSION

  s.homepage    = "https://github.com/sstephenson/execjs"
  s.summary     = "Run JavaScript code from Ruby"
  s.description = <<-EOS
    ExecJS lets you run JavaScript code from Ruby.
  EOS

  s.files = [
    "lib/execjs.rb",
    "lib/execjs/external_runtime.rb",
    "lib/execjs/johnson_runtime.rb",
    "lib/execjs/module.rb",
    "lib/execjs/version.rb",
    "lib/execjs/mustang_runtime.rb",
    "lib/execjs/ruby_racer_runtime.rb",
    "lib/execjs/ruby_rhino_runtime.rb",
    "lib/execjs/runtimes.rb",
    "lib/execjs/support/basic_runner.js",
    "lib/execjs/support/jsc_runner.js",
    "lib/execjs/support/jscript_runner.js",
    "lib/execjs/support/json2.js",
    "lib/execjs/support/node_runner.js",
    "lib/execjs/support/which.bat",
    "LICENSE",
    "README.md"
  ]

  s.add_dependency "multi_json", "~>1.0"
  s.add_development_dependency "johnson"
  s.add_development_dependency "mustang"
  s.add_development_dependency "rake"
  s.add_development_dependency "therubyracer"
  s.add_development_dependency "therubyrhino"

  s.authors = ["Sam Stephenson", "Josh Peek"]
  s.email   = ["sstephenson@gmail.com", "josh@joshpeek.com"]
end
