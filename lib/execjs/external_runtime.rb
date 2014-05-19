require "shellwords"
require "tempfile"
require "execjs/runtime"

module ExecJS
  class ExternalRuntime < Runtime
    class Context < Runtime::Context
      def initialize(runtime, source = "")
        source = encode(source)

        @runtime = runtime
        @source  = source
      end

      def eval(source, options = {})
        source = encode(source)

        if /\S/ =~ source
          exec("return eval(#{::JSON.generate("(#{source})", :quirks_mode => true)})")
        end
      end

      def exec(source, options = {})
        source = encode(source)
        source = "#{@source}\n#{source}" if @source

        compile_to_tempfile(source) do |file|
          if ExecJS.cygwin?
            filepath = `cygpath -m #{file.path}`.rstrip
          else
            filepath = file.path
          end
          extract_result(@runtime.send(:exec_runtime, filepath))
        end
      end

      def call(identifier, *args)
        eval "#{identifier}.apply(this, #{::JSON.generate(args)})"
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
              encoded_source = encode_unicode_codepoints(source)
              ::JSON.generate("(function(){ #{encoded_source} })()", :quirks_mode => true)
            end
            output.sub!('#{json2_source}') do
              IO.read(ExecJS.root + "/support/json2.js")
            end
          end
        end

        def extract_result(output)
          status, value = output.empty? ? [] : ::JSON.parse(output, :create_additions => false)
          if status == "ok"
            value
          elsif value =~ /SyntaxError:/
            raise RuntimeError, value
          else
            raise ProgramError, value
          end
        end

        def encode_unicode_codepoints(str)
          str.gsub(/[\u0080-\uffff]/) do |ch|
            "\\u%04x" % ch.codepoints.to_a
          end
        end
    end

    attr_reader :name

    def initialize(options)
      @name        = options[:name]
      @command     = options[:command]
      @runner_path = options[:runner_path]
      @encoding    = options[:encoding]
      @deprecated  = !!options[:deprecated]
      @binary      = nil
    end

    def available?
      require 'json'
      binary ? true : false
    end

    def deprecated?
      @deprecated
    end

    private
      def binary
        @binary ||= which(@command)
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

      def exec_runtime(filename)
        output = sh("#{shell_escape(*(binary.split(' ') << filename))} 2>&1")
        if $?.success?
          output
        else
          raise RuntimeError, output
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

      def sh(command)
        output, options = nil, {}
        options[:external_encoding] = @encoding if @encoding
        options[:internal_encoding] = ::Encoding.default_internal || 'UTF-8'
        IO.popen(command, options) { |f| output = f.read }
        output
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
