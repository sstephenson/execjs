require "shellwords"
require "tempfile"

module ExecJS
  class ExternalRuntime
    class Context
      def initialize(runtime, source = "")
        source = source.encode('UTF-8') if source.respond_to?(:encode)

        @runtime = runtime
        @source  = source
      end

      def eval(source, options = {})
        source = source.encode('UTF-8') if source.respond_to?(:encode)

        if /\S/ =~ source
          exec("return eval(#{MultiJson.encode("(#{source})")})")
        end
      end

      def exec(source, options = {})
        source = source.encode('UTF-8') if source.respond_to?(:encode)
        source = "#{@source}\n#{source}" if @source

        compile_to_tempfile(source) do |file|
          extract_result(@runtime.send(:exec_runtime, file.path))
        end
      end

      def call(identifier, *args)
        eval "#{identifier}.apply(this, #{MultiJson.encode(args)})"
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
              MultiJson.encode("(function(){ #{encoded_source} })()")
            end
            output.sub!('#{json2_source}') do
              IO.read(ExecJS.root + "/support/json2.js")
            end
          end
        end

        def extract_result(output)
          status, value = output.empty? ? [] : MultiJson.decode(output)
          if status == "ok"
            value
          elsif value =~ /SyntaxError:/
            raise RuntimeError, value
          else
            raise ProgramError, value
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
      require "multi_json"
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
            File.executable? File.join(p, cmd)
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
