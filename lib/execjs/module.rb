require "execjs/version"
require "rbconfig"

module ExecJS
  class Error < ::StandardError; 
    attr_accessor :js_trace
    
    def initialize(msg, js_trace = false)
      @js_trace = js_trace
      super msg
    end
  end

  class RuntimeError              < Error; end
  class ProgramError              < Error; end
  class RuntimeUnavailable < RuntimeError; end

  class << self
    attr_reader :runtime

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
      @root ||= File.expand_path("..", __FILE__)
    end

    def windows?
      @windows ||= RbConfig::CONFIG["host_os"] =~ /mswin|mingw/
    end

    if defined? Encoding
      if (!defined?(RUBY_ENGINE) || (RUBY_ENGINE != "jruby" && RUBY_ENGINE != "rbx"))
        def encode(string)
          string.encode('UTF-8')
        end
      else
        # workaround for jruby bug http://jira.codehaus.org/browse/JRUBY-6588
        # workaround for rbx bug https://github.com/rubinius/rubinius/issues/1729
        def encode(string)
          if string.encoding.name == 'ASCII-8BIT'
            data = string.dup
            data.force_encoding('utf-8')

            unless data.valid_encoding?
              raise Encoding::UndefinedConversionError, "Could not encode ASCII-8BIT data #{string.dump} as UTF-8"
            end
          else
            data = string.encode('utf-8')
          end
          data
        end
      end
    else
      # Define no-op on 1.8
      def encode(string)
        string
      end
    end

    def trace_line(source, line, column, name = '<eval>')
      line = line.to_i
      source = source.lines.to_a if source.respond_to?(:lines)
      if line > 0 && source.length >= line
        code = source[line - 1]
      else
        code = source[0]
      end
      code.strip! if code.respond_to?(:strip!)
      "at #{code} (#{name}:#{line}:#{column})"
    end
  end
end
