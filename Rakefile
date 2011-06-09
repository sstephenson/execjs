require "rake/testtask"

task :default => :test

$:.unshift File.expand_path("../lib", __FILE__)
require "execjs"

tests = namespace :test do |tests|
  ExecJS::Runtimes.names.each do |name|
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
end
