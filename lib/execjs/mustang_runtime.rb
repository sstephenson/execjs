module ExecJS
  class MustangRuntime
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

module ExecJS
  class MustangRuntime::Context

    def initialize(source = "")
      @v8_context = ::Mustang::Context.new
      @v8_context.eval(source)
    end

    def exec(source, options = {})
      if /\S/ =~ source
        eval "(function(){#{source}})()", options
      end
    end

    def eval(source, options = {})
      if /\S/ =~ source
        unbox @v8_context.eval("(#{source})")
      end
    end

    def call(properties, *args)
      unbox @v8_context.eval(properties).call(*args)
    rescue NoMethodError
      raise ProgramError
    end

    def unbox(value)
      case value
      when V8::NullClass, V8::Function, V8::UndefinedClass
        nil
      when V8::Array
        value.map { |v| unbox(v) }
      when V8::Object
        value.inject({}) do |vs, (k, v)|
          vs[k] = unbox(v) unless v.is_a?(::V8::Function)
        vs
        end
      when V8::SyntaxError
        raise RuntimeError
      when V8::Error
        raise ProgramError
      else
        value
      end
    end

  end
end
