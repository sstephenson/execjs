module ExecJS
  class MustangRuntime
    class Context
      def initialize(source = "")
        source = ExecJS.encode(source)

        @v8_context = ::Mustang::Context.new
        @v8_context.eval(source)
      end

      def exec(source, options = {})
        source = ExecJS.encode(source)

        if /\S/ =~ source
          eval "(function(){#{source}})()", options
        end
      end

      def eval(source, options = {})
        source = ExecJS.encode(source)

        if /\S/ =~ source
          unbox @v8_context.eval(save_string_error source)
        end
      end

      def call(properties, *args)
        unbox @v8_context.eval(properties).call(*args)
      rescue NoMethodError => e
        raise ProgramError, e.message
      end

      def unbox(value)
        case value
        when Mustang::V8::Array
          value.map { |v| unbox(v) }
        when Mustang::V8::Boolean
          value.to_bool
        when Mustang::V8::NullClass, Mustang::V8::UndefinedClass
          nil
        when Mustang::V8::Function
          nil
        when Mustang::V8::SyntaxError
          message, trace = process_error(value)
          raise RuntimeError.new(message, trace)
        when Mustang::V8::Error
          message, trace = process_error(value)
          raise ProgramError.new(message, trace)
        when Mustang::V8::Object
          value.inject({}) { |h, (k, v)|
            v = unbox(v)
            h[k] = v if v
            h
          }
        else
          value.respond_to?(:delegate) ? value.delegate : value
        end
      end

      # workaround for https://github.com/nu7hatch/mustang/issues/20
      def save_string_error(source)
        "
        try {
          (#{source})
        } catch(e) {
          if (typeof e == 'string') {
            throw new Error(e);
          } else {
            throw e;
          }
        }"
      end

      protected
        def process_error(error)
          # error.line_no
          # error.start_col
          # error.script_name
          # error.source_line
          [error.message, nil]
        end
    end

    def name
      "Mustang (V8)"
    end

    def exec(source)
      context = Context.new
      context.exec(source)
    end

    def eval(source)
      context = Context.new
      context.eval(source)
    end

    def compile(source)
      Context.new(source)
    end

    def available?
      require "mustang"
      true
    rescue LoadError
      false
    end
  end
end
