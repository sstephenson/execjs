# -*- coding: utf-8 -*-
require "execjs"
require "test/unit"

module TestRuntime
  def test_exec
    assert_nil @runtime.exec("1")
    assert_nil @runtime.exec("return")
    assert_nil @runtime.exec("return null")
    assert_nil @runtime.exec("return function() {}")
    assert_equal 0, @runtime.exec("return 0")
    assert_equal true, @runtime.exec("return true")
    assert_equal [1, 2], @runtime.exec("return [1, 2]")
    assert_equal "hello", @runtime.exec("return 'hello'")
    assert_equal({"a"=>1,"b"=>2}, @runtime.exec("return {a:1,b:2}"))
    assert_equal "café", @runtime.exec("return 'café'")
    assert_equal "\\", @runtime.exec('return "\\\\"')
  end

  def test_eval
    assert_nil @runtime.eval("")
    assert_nil @runtime.eval(" ")
    assert_nil @runtime.eval("null")
    assert_nil @runtime.eval("function() {}")
    assert_equal 0, @runtime.eval("0")
    assert_equal true, @runtime.eval("true")
    assert_equal [1, 2], @runtime.eval("[1, 2]")
    assert_equal "hello", @runtime.eval("'hello'")
    assert_equal({"a"=>1,"b"=>2}, @runtime.eval("{a:1,b:2}"))
    assert_equal "café", @runtime.eval("'café'")
    assert_equal "\\", @runtime.eval('"\\\\"')
  end

  def test_compile
    context = @runtime.compile("foo = function() { return \"bar\"; }")
    assert_equal "bar", context.exec("return foo()")
    assert_equal "bar", context.eval("foo()")
    assert_equal "bar", context.call("foo")
  end

  def test_this_is_global_scope
    assert_equal true, @runtime.eval("this === (function() {return this})()")
    assert_equal true, @runtime.exec("return this === (function() {return this})()")
  end

  def test_syntax_error
    assert_raise ExecJS::RuntimeError do
      @runtime.exec(")")
    end
  end

  def test_thrown_exception
    assert_raise ExecJS::ProgramError do
      @runtime.exec("throw 'hello'")
    end
  end
end

runtimes = [
  "Mustang",
  "RubyRacer",
  "RubyRhino",
  "Node",
  "JavaScriptCore",
  "Spidermonkey",
 "JScript"]

warn "Runtime Support:"
runtimes.each do |name|
  runtime = ExecJS::Runtimes.const_get(name)
  ok = runtime.available?

  warn " %s %-21s %s" %
    if ok
      ["✓", runtime.name, "Found"]
    else
      [" ", runtime.name, "Not found"]
    end

  if ok
    klass_name = "Test#{name}"
    instance_eval "class ::#{klass_name} < Test::Unit::TestCase; end"
    test_suite = Kernel.const_get(klass_name)

    test_suite.instance_eval do
      include TestRuntime

      instance_exec do
        define_method(:name) do
          runtime.name
        end
      end

      define_method(:setup) do
        instance_variable_set(:@runtime, runtime)
      end
    end
  end
end
warn ""
