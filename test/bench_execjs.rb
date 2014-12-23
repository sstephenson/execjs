require 'benchmark'
require 'execjs'

TIMES = 10
SOURCE = File.read(File.expand_path("../fixtures/coffee-script.js", __FILE__)).freeze

Benchmark.bmbm do |x|
  ExecJS::Runtimes.runtimes.each do |runtime|
    next if !runtime.available? || runtime.deprecated?

    x.report(runtime.name) do
      ExecJS.runtime = runtime
      context = ExecJS.compile(SOURCE)

      TIMES.times do
        context.call("CoffeeScript.eval", "((x) -> x * x)(8)")
      end
    end
  end
end
