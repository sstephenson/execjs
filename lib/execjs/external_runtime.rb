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
          exec("return eval(#{JSON.encode("(#{source})")})", options)
        end
      end

      def exec(source, options = {})
        source = encode(source)
        source = "#{@source}\n#{source}" if @source

        compile_to_tempfile(source) do |file|
          extract_result(@runtime.send(:exec_runtime, options[:timeout], file.path))
        end
      end

      def call(identifier, *args)
        eval "#{identifier}.apply(this, #{JSON.encode(args)})"
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
              JSON.encode("(function(){ #{encoded_source} })()")
            end
            output.sub!('#{json2_source}') do
              IO.read(ExecJS.root + "/support/json2.js")
            end
          end
        end

        def extract_result(output)
          status, value = output.empty? ? [] : JSON.decode(output)
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

    @@supports_force_encoding = ''.respond_to?(:force_encoding)

    attr_reader :name

    def initialize(options)
      @name        = options[:name]
      @command     = options[:command]
      @runner_path = options[:runner_path]
      @test_args   = options[:test_args]
      @test_match  = options[:test_match]
      @encoding    = options[:encoding]
      @deprecated  = !!options[:deprecated]
      @binary      = nil
    end

    def available?
      require "execjs/json"
      binary ? true : false
    end

    def deprecated?
      @deprecated
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

      def build_command(file_name)
        if RUBY_VERSION < '1.9'
          "#{shell_escape(*(binary.split(' ') << file_name))} 2>&1"
        else
          binary.split(' ') << file_name << {:err => [:child, :out]}
        end
      end

      def popen(timeout, command, options)
        status = nil
        if RUBY_VERSION < '1.9'
          IO.popen(command) {|f| yield f}
          status = $?
        else
          pid = nil
          begin
            with_timeout(timeout) do
              IO.popen(command, options) do |f|
                pid = f.pid
                yield f
              end
              status = $?
            end
          rescue Timeout::Error
            if !pid.nil?
              Process.kill 'KILL', pid
              Process.wait pid
            end
            raise
          end
        end
        status
      end

      def with_timeout(timeout)
        return yield if timeout.nil? or timeout.zero?

        result, timed_out = nil, true

        worker_thread = Thread.new do
          result = yield
          timed_out = false
        end

        timeout_thread = Thread.new do
          sleep timeout
          if worker_thread.alive?
            worker_thread.kill
            sleep 0
            worker_thread.raise
          end
        end

        worker_thread.join
        timeout_thread.kill
        raise Timeout::Error if timed_out
        result
      end

    protected
      def runner_source
        @runner_source ||= IO.read(@runner_path)
      end

      def exec_runtime(timeout, file_name)
        command = build_command(file_name)
        status, output = sh(timeout, command)
        if status.success?
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

      def sh(timeout, command)
        status, output, options = nil, nil, {}

        if @@supports_force_encoding
          options[:external_encoding] = @encoding if @encoding
          options[:internal_encoding] = ::Encoding.default_internal || 'UTF-8'
        end

        status = popen(timeout, command, options) do |f|
          output = f.read
        end

        if not @@supports_force_encoding
          require 'iconv'
          output = Iconv.new('UTF-8', @encoding).iconv(output) if @encoding
        end

        [status, output]
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

