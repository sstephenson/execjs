require "execjs/runtime"
require "json"

module ExecJS
  class NashornRuntime < Runtime
    class Context < Runtime::Context
      def initialize(runtime, source = "")
        @nashorn_context = javax.script.ScriptEngineManager.new().getEngineByName("nashorn")

        exec source
      end

      def exec(source, options = {})
        if /\S/ =~ source
          eval "(function(){#{source}})()", options
        end
      end

      def eval(source, options = {})
        source = encode(source)

        if /\S/ =~ source
          JSON.parse(@nashorn_context.eval("JSON.stringify([#{source}])"))[0]
        end
      rescue Java::JavaxScript::ScriptException => e
        if e.message =~ /^\<eval\>/
          raise RuntimeError, e.message
        else
          raise ProgramError, e.message
        end
      end

      def call(properties, *args)
        eval "#{properties}.apply(this, #{JSON.dump(args)})"
      end
    end

    def name
      "nashorn (Java 8)"
    end

    def available?
      javax.script.ScriptEngineManager.new().getEngineByName("nashorn") != nil
    rescue
      false
    end
  end
end
