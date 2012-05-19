require "multi_json"
require "shellwords"
require "tempfile"

module ExecJS
  class ExternalRuntime
    class << self
      def extract_error(output, source)
        match_data = /^.*\((\d+), (\d+)\).*Microsoft JScript( runtime error)?: (.*)$/.match(output)
        if match_data
          line, column, message, message = match_data.to_a[1,4]
          line = line.to_i - 1
          trace = [ExecJS.trace_line(source, line, column)]
        else
          message = output
          trace = false
        end
        [message, trace]
      end
    end

    class Context
      def initialize(runtime, source = "")
        source = ExecJS.encode(source)

        @runtime = runtime
        @source  = source
      end

      def eval(source, options = {})
        source = ExecJS.encode(source)

        if /\S/ =~ source
          exec("return eval(#{json_encode("(#{source})")})")
        end
      end

      def exec(source, options = {})
        source = ExecJS.encode(source)
        source = "#{@source}\n#{source}" if /\S/ =~ @source

        compile_to_tempfile(source) do |file|
          extract_result(@runtime.send(:exec_runtime, file.path, source), source)
        end
      end

      def call(identifier, *args)
        eval "#{identifier}.apply(this, #{json_encode(args)})"
      end

      protected
        def compile_to_tempfile(source)
          tempfile = Tempfile.open(['execjs', '.js'])
          tempfile.write compile(source)
          tempfile.close
          yield tempfile
        ensure
          tempfile.close!
        end

        def compile(source)
          @runtime.send(:runner_source).dup.tap do |output|
            output.sub!('#{source}') do
              source
            end
            output.sub!('#{encoded_source}') do
              encode_unicode_codepoints(source)
            end
            output.sub!('#{escaped_source}') do
              encoded_source = encode_unicode_codepoints(source)
              json_encode("(function(){ #{encoded_source} })()")
            end
            output.sub!('#{json2_source}') do
              IO.read(ExecJS.root + "/support/json2.js")
            end
          end
        end

        def process_trace(trace, source)
          if trace.respond_to?(:lines)
            trace = trace.lines.to_a
            trace = trace[1, trace.length - 8]
            trace.map! do |i|
              line, column = /^at .*:(\d+):(\d+)\)?$/.match(i.strip).to_a[1,2]
              line = line.to_i - 1
              ExecJS.trace_line(source, line, column)
            end
          end
          trace
        end

        def extract_result(output, source)
          begin
            status, value, trace = output.empty? ? [] : json_decode(output)
            trace = process_trace(trace, source) if status != "ok"
          rescue
            status = 'err'
            value, trace = ExternalRuntime::extract_error(output, source)
          end

          if status == "ok"
            value
          elsif value =~ /SyntaxError:/
            raise RuntimeError.new(value, trace)
          else
            raise ProgramError.new(value, trace)
          end
        end

        if "".respond_to?(:codepoints)
          def encode_unicode_codepoints(str)
            str.gsub(/[\u0080-\uffff]/) do |ch|
              "\\u%04x" % ch.codepoints.to_a
            end
          end
        else
          def encode_unicode_codepoints(str)
            str.gsub(/([\xC0-\xDF][\x80-\xBF]|
                       [\xE0-\xEF][\x80-\xBF]{2}|
                       [\xF0-\xF7][\x80-\xBF]{3})+/nx) do |ch|
              "\\u%04x" % ch.unpack("U*")
            end
          end
        end

        if MultiJson.respond_to?(:dump)
          def json_decode(obj)
            MultiJson.load(obj)
          end

          def json_encode(obj)
            MultiJson.dump(obj)
          end
        else
          def json_decode(obj)
            MultiJson.decode(obj)
          end

          def json_encode(obj)
            MultiJson.encode(obj)
          end
        end
    end

    attr_reader :name

    def initialize(options)
      @name        = options[:name]
      @command     = options[:command]
      @runner_path = options[:runner_path]
      @test_args   = options[:test_args]
      @test_match  = options[:test_match]
      @encoding    = options[:encoding]
      @binary      = nil
    end

    def exec(source)
      context = Context.new(self)
      context.exec(source)
    end

    def eval(source)
      context = Context.new(self)
      context.eval(source)
    end

    def compile(source)
      Context.new(self, source)
    end

    def available?
      binary ? true : false
    end

    private
      def binary
        @binary ||= locate_binary
      end

      def locate_executable(cmd)
        if ExecJS.windows? && File.extname(cmd) == ""
          cmd << ".exe"
        end

        if File.executable? cmd
          cmd
        else
          path = ENV['PATH'].split(File::PATH_SEPARATOR).find { |p|
            full_path = File.join(p, cmd)
            File.executable?(full_path) && File.file?(full_path)
          }
          path && File.expand_path(cmd, path)
        end
      end

    protected
      def runner_source
        @runner_source ||= IO.read(@runner_path)
      end

      def exec_runtime(filename, source)
        output = sh("#{shell_escape(*(binary.split(' ') << filename))} 2>&1")
        if $?.success?
          output
        else
          value, trace = ExternalRuntime.extract_error(output, source)
          raise RuntimeError.new(value, trace)
        end
      end

      def locate_binary
        if binary = which(@command)
          if @test_args
            output = `#{shell_escape(binary, @test_args)} 2>&1`
            binary if output.match(@test_match)
          else
            binary
          end
        end
      end

      def which(command)
        Array(command).find do |name|
          name, args = name.split(/\s+/, 2)
          path = locate_executable(name)

          next unless path

          args ? "#{path} #{args}" : path
        end
      end

      if "".respond_to?(:force_encoding)
        def sh(command)
          output, options = nil, {}
          options[:external_encoding] = @encoding if @encoding
          options[:internal_encoding] = Encoding.default_internal || 'UTF-8'
          IO.popen(command, options) { |f| output = f.read }
          output
        end
      else
        require "iconv"

        def sh(command)
          output = nil
          IO.popen(command) { |f| output = f.read }

          if @encoding
            Iconv.new('UTF-8', @encoding).iconv(output)
          else
            output
          end
        end
      end

      if ExecJS.windows?
        def shell_escape(*args)
          # see http://technet.microsoft.com/en-us/library/cc723564.aspx#XSLTsection123121120120
          args.map { |arg|
            arg = %Q("#{arg.gsub('"','""')}") if arg.match(/[&|()<>^ "]/)
            arg
          }.join(" ")
        end
      else
        def shell_escape(*args)
          Shellwords.join(args)
        end
      end
  end
end
