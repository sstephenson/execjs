require "rake/testtask"
require "bundler/gem_tasks"

task :default => :test

$:.unshift File.expand_path("../lib", __FILE__)
require "execjs/runtimes"

tests = namespace :test do |tests|
  ExecJS::Runtimes.names.each do |name|
    next if ExecJS::Runtimes.const_get(name).deprecated?

    task(name.downcase) do
      ENV["EXECJS_RUNTIME"] = name.to_s
    end

    Rake::TestTask.new(name.downcase) do |t|
      t.libs << "test"
      t.warning = true
    end
  end
end

def banner(text)
  warn ""
  warn "=" * Rake.application.terminal_width
  warn text
  warn "=" * Rake.application.terminal_width
  warn ""
end

desc "Run tests for all installed runtimes"
task :test do
  passed  = []
  failed  = []
  skipped = []

  tests.tasks.each do |task|
    banner "Running #{task.name}"

    begin
      task.invoke
    rescue SignalException => e
      if e.message == "2"
        skipped << task.name
      else
        failed << task.name
      end
    rescue Exception => e
      if e.message[/Command failed with status \((\d+)\)/, 1] == "2"
        skipped << task.name
      else
        failed << task.name
      end
    else
      passed << task.name
    end
  end

  messages = ["PASSED:  #{passed.join(", ")}"]
  messages << "SKIPPED: #{skipped.join(", ")}" if skipped.any?
  messages << "FAILED:  #{failed.join(", ")}" if failed.any?
  banner messages.join("\n")

  raise "test failures" if failed.any?
  raise "all tests skipped" if !passed.any?
end
