require "execjs/runtime"
require "open3"
require "thread"

module ExecJS
  class PersistentExternalRuntime < Runtime
    class Context < Runtime::Context
      def initialize(runtime, source = "")
        source = encode(source)

        object_id = self.object_id

        ObjectSpace.define_finalizer(self, proc do
          source = JSON.dump([object_id])+"\n"

          runtime.send(:exec_runtime, source)
        end)

        @runtime = runtime

        eval source
      end

      def eval(source, options = {})
        source = encode(source)
        source = JSON.dump([self.object_id, source])+"\n"

        extract_result(@runtime.send(:exec_runtime, source))
      end

      def exec(source, options = {})
        source = encode(source)

        if /\S/ =~ source
          eval "(function(){#{source}})()", options
        end
      end

      def call(identifier, *args)
        eval "#{identifier}.apply(this, #{::JSON.generate(args)})"
      end

      protected

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
    end

    attr_reader :name

    def initialize(options)
      @name        = options[:name]
      @command     = options[:command]
      @runner_path = options[:runner_path]
      @test_match  = options[:test_match]
      @encoding    = options[:encoding]
      @deprecated  = !!options[:deprecated]
      @binary      = nil
      @mutex       = Mutex.new
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
      def exec_runtime(source)
        @mutex.synchronize do
          unless defined? @stdout
            @stdin, @stdout = Open3.popen3(*(binary.split(' ') << @runner_path))
          end
          @stdin.write(source)
          @stdin.flush
          @stdout.readline
        end
      end

      def locate_binary
        if binary = which(@command)
          binary
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
  end
end
