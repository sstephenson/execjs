module ExecJS
  module Runtimes
    RubyRacer = RubyRacerRuntime.new

    RubyRhino = RubyRhinoRuntime.new

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


    def self.best_available
      runtimes.find(&:available?) or raise(ExecJS::RuntimeError, 'Could not find any JavaScript runtime!')
    end

    def self.runtimes
      @runtimes ||= [
        RubyRacer,
        RubyRhino,
        Node,
        JavaScriptCore,
        Spidermonkey,
        JScript
      ]
    end
  end
end
