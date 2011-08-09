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

        compile_to_tempfile([@source, source].join("\n")) do |file|
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
          elsif value == "SyntaxError: Parse error"
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
      @binary      = locate_binary
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
      @binary ? true : false
    end

    protected
      def runner_source
        @runner_source ||= IO.read(@runner_path)
      end

      def exec_runtime(filename)
        output = nil
        IO.popen("#{@binary} #{filename} 2>&1") { |f| output = f.read }
        if $?.success?
          output
        else
          raise RuntimeError, output
        end
      end

      def locate_binary
        if binary = which(@command)
          if @test_args
            output = `#{binary} #{@test_args} 2>&1`
            binary if output.match(@test_match)
          else
            binary
          end
        end
      end

      def which(command)
        Array(command).each do |name|
          name, args = name.split(/\s+/, 2)
          result = if ExecJS.windows?
            `"#{ExecJS.root}/support/which.bat" #{name}`
          else
            `command -v #{name} 2>/dev/null`
          end

          if path = result.strip.split("\n").first
            return args ? "#{path} #{args}" : path
          end
        end
        nil
      end
  end
end
