require "rbconfig"

module ExecJS
  VERSION = "1.1.2"

  class Error           < ::StandardError; end
  class RuntimeError              < Error; end
  class ProgramError              < Error; end
  class RuntimeUnavailable < RuntimeError; end

  class << self
    def runtimes
      Runtimes.runtimes
    end

    def runtime
      @runtime ||= Runtimes.autodetect
    end

    def runtime=(runtime)
      raise RuntimeUnavailable, "#{runtime.name} is unavailable on this system" unless runtime.available?
      @runtime = runtime
    end

    def exec(source)
      runtime.exec(source)
    end

    def eval(source)
      runtime.eval(source)
    end

    def compile(source)
      runtime.compile(source)
    end

    def root
      @root ||= File.expand_path("../execjs", __FILE__)
    end

    def windows?
      @windows ||= RbConfig::CONFIG["host_os"] =~ /mswin|mingw/
    end
  end
end

require "execjs/runtimes"
