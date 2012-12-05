require "execjs/runtime"

module ExecJS
  class RubyRhinoRuntime < Runtime
    class Context < Runtime::Context
      def initialize(runtime, source = "")
        source = encode(source)

        @rhino_context = ::Rhino::Context.new
        fix_memory_limit! @rhino_context if fix_memory_limit?
        @rhino_context.eval(source)
      end

      def exec(source, options = {})
        source = encode(source)

        if /\S/ =~ source
          eval "(function(){#{source}})()", options
        end
      end

      def eval(source, options = {})
        source = encode(source)

        if /\S/ =~ source
          unbox @rhino_context.eval("(#{source})")
        end
      rescue ::Rhino::JSError => e
        if e.message =~ /^syntax error/
          raise RuntimeError, e.message
        else
          raise ProgramError, e.message
        end
      end

      def call(properties, *args)
        unbox @rhino_context.eval(properties).call(*args)
      rescue ::Rhino::JSError => e
        if e.message == "syntax error"
          raise RuntimeError, e.message
        else
          raise ProgramError, e.message
        end
      end

      def unbox(value)
        case value = ::Rhino::to_ruby(value)
        when ::Rhino::JS::Function
          nil
        when ::Rhino::JS::NativeObject
          value.inject({}) do |vs, (k, v)|
            case v
            when ::Rhino::JS::Function
              nil
            else
              vs[k] = unbox(v)
            end
            vs
          end
        when Array
          value.map { |v| unbox(v) }
        else
          value
        end
      end

      private
        # Disables bytecode compiling which limits you to 64K scripts
        def fix_memory_limit!(context)
          if context.respond_to?(:optimization_level=)
            context.optimization_level = -1
          else
            context.instance_eval { @native.setOptimizationLevel(-1) }
          end
        end

        @@fix_memory_limit = nil

        def fix_memory_limit?
          return @@fix_memory_limit unless @@fix_memory_limit.nil?
          version = defined?(::Rhino::VERSION) && ::Rhino::VERSION
          if version && Gem::Version.create(version) >= Gem::Version.create('2.0.2')
            @@fix_memory_limit = false
          else
            @@fix_memory_limit = true
          end
        end
    end

    def name
      "therubyrhino (Rhino)"
    end

    def available?
      require "rhino"
      true
    rescue LoadError
      false
    end
  end
end
