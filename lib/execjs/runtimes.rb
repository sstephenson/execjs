require "execjs/external_runtime"
require "execjs/mustang_runtime"
require "execjs/ruby_racer_runtime"
require "execjs/ruby_rhino_runtime"

module ExecJS
  module Runtimes
    RubyRacer = RubyRacerRuntime.new

    RubyRhino = RubyRhinoRuntime.new

    Mustang = MustangRuntime.new

    Node = ExternalRuntime.new(
      :name        => "Node.js (V8)",
      :command     => ["nodejs", "node"],
      :runner_path => ExecJS.root + "/support/node_runner.js"
    )

    JavaScriptCore = ExternalRuntime.new(
      :name        => "JavaScriptCore",
      :command     => "/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Resources/jsc",
      :runner_path => ExecJS.root + "/support/basic_runner.js",
      :conversion => { :from => "ISO8859-1", :to => "UTF-8" }
    )

    Spidermonkey = ExternalRuntime.new(
      :name        => "Spidermonkey",
      :command     => "js",
      :runner_path => ExecJS.root + "/support/basic_runner.js"
    )

    JScript = ExternalRuntime.new(
      :name        => "JScript",
      :command     => "cscript //E:jscript //Nologo",
      :runner_path => ExecJS.root + "/support/jscript_runner.js"
    )


    def self.autodetect
      from_environment || best_available ||
        raise(RuntimeUnavailable, "Could not find a JavaScript runtime. " +
          "See https://github.com/sstephenson/execjs for a list of available runtimes.")
    end

    def self.best_available
      runtimes.find(&:available?)
    end

    def self.from_environment
      if name = ENV["EXECJS_RUNTIME"]
        if runtime = const_get(name)
          if runtime.available?
            runtime if runtime.available?
          else
            raise RuntimeUnavailable, "#{name} runtime is not available on this system"
          end
        elsif !name.empty?
          raise RuntimeUnavailable, "#{name} runtime is not defined"
        end
      end
    end

    def self.names
      constants
    end

    def self.runtimes
      @runtimes ||= [
        RubyRacer,
        RubyRhino,
        Mustang,
        Node,
        JavaScriptCore,
        Spidermonkey,
        JScript
      ]
    end
  end
end
