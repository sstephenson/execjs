require "rbconfig"

module ExecJS
  class Error < ::StandardError; end
  class RuntimeError    < Error; end
  class ProgramError    < Error; end

  autoload :ExternalRuntime,  "execjs/external_runtime"
  autoload :MustangRuntime,   "execjs/mustang_runtime"
  autoload :RubyRacerRuntime, "execjs/ruby_racer_runtime"
  autoload :RubyRhinoRuntime, "execjs/ruby_rhino_runtime"
  autoload :Runtimes,         "execjs/runtimes"

  def self.exec(source)
    runtime.exec(source)
  end

  def self.eval(source)
    runtime.eval(source)
  end

  def self.compile(source)
    runtime.compile(source)
  end

  def self.runtimes
    Runtimes.runtimes
  end

  def self.runtime
    @runtime ||= Runtimes.best_available ||
      raise(ExecJS::RuntimeError, "Could not find a JavaScript runtime")
  end

  def self.root
    @root ||= File.expand_path("../execjs", __FILE__)
  end

  def self.windows?
    @windows ||= RbConfig::CONFIG["host_os"] =~ /mswin|mingw/
  end
end
