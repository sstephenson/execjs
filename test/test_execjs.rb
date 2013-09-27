# -*- coding: utf-8 -*-
require "test/unit"
require "execjs/module"

begin
  require "execjs"
rescue ExecJS::RuntimeUnavailable => e
  warn e
  exit 2
end

class TestExecJS < Test::Unit::TestCase
  def test_runtime_available
    runtime = ExecJS::ExternalRuntime.new(:command => "nonexistent")
    assert !runtime.available?

    runtime = ExecJS::ExternalRuntime.new(:command => "ruby")
    assert runtime.available?
  end

  def test_runtime_assignment
    original_runtime = ExecJS.runtime
    runtime = ExecJS::ExternalRuntime.new(:command => "nonexistent")
    assert_raises(ExecJS::RuntimeUnavailable) { ExecJS.runtime = runtime }
    assert_equal original_runtime, ExecJS.runtime

    runtime = ExecJS::ExternalRuntime.new(:command => "ruby")
    ExecJS.runtime = runtime
    assert_equal runtime, ExecJS.runtime
  ensure
    ExecJS.runtime = original_runtime
  end

  def test_context_call
    context = ExecJS.compile("id = function(v) { return v; }")
    assert_equal "bar", context.call("id", "bar")
  end

  def test_nested_context_call
    context = ExecJS.compile("a = {}; a.b = {}; a.b.id = function(v) { return v; }")
    assert_equal "bar", context.call("a.b.id", "bar")
  end

  def test_context_call_missing_function
    context = ExecJS.compile("")
    assert_raises ExecJS::ProgramError do
      context.call("missing")
    end
  end

  def test_exec
    assert_nil ExecJS.exec("1")
    assert_nil ExecJS.exec("return")
    assert_nil ExecJS.exec("return null")
    assert_nil ExecJS.exec("return function() {}")
    assert_equal 0, ExecJS.exec("return 0")
    assert_equal true, ExecJS.exec("return true")
    assert_equal [1, 2], ExecJS.exec("return [1, 2]")
    assert_equal "hello", ExecJS.exec("return 'hello'")
    assert_equal({"a"=>1,"b"=>2}, ExecJS.exec("return {a:1,b:2}"))
    assert_equal "café", ExecJS.exec("return 'café'")
    assert_equal "☃", ExecJS.exec('return "☃"')
    assert_equal "☃", ExecJS.exec('return "\u2603"')
    assert_equal "\\", ExecJS.exec('return "\\\\"')
  end

  def test_eval
    assert_nil ExecJS.eval("")
    assert_nil ExecJS.eval(" ")
    assert_nil ExecJS.eval("null")
    assert_nil ExecJS.eval("function() {}")
    assert_equal 0, ExecJS.eval("0")
    assert_equal true, ExecJS.eval("true")
    assert_equal [1, 2], ExecJS.eval("[1, 2]")
    assert_equal [1, nil], ExecJS.eval("[1, function() {}]")
    assert_equal "hello", ExecJS.eval("'hello'")
    assert_equal ["red", "yellow", "blue"], ExecJS.eval("'red yellow blue'.split(' ')")
    assert_equal({"a"=>1,"b"=>2}, ExecJS.eval("{a:1,b:2}"))
    assert_equal({"a"=>true}, ExecJS.eval("{a:true,b:function (){}}"))
    assert_equal "café", ExecJS.eval("'café'")
    assert_equal "☃", ExecJS.eval('"☃"')
    assert_equal "☃", ExecJS.eval('"\u2603"')
    assert_equal "\\", ExecJS.eval('"\\\\"')
  end

  if defined? Encoding
    def test_encoding
      utf8 = Encoding.find('UTF-8')

      assert_equal utf8, ExecJS.exec("return 'hello'").encoding
      assert_equal utf8, ExecJS.eval("'☃'").encoding

      ascii = "'hello'".encode('US-ASCII')
      result = ExecJS.eval(ascii)
      assert_equal "hello", result
      assert_equal utf8, result.encoding

      assert_raise Encoding::UndefinedConversionError do
        binary = "\xde\xad\xbe\xef".force_encoding("BINARY")
        ExecJS.eval(binary)
      end
    end

    def test_encoding_compile
      utf8 = Encoding.find('UTF-8')

      context = ExecJS.compile("foo = function(v) { return '¶' + v; }".encode("ISO8859-15"))

      assert_equal utf8, context.exec("return foo('hello')").encoding
      assert_equal utf8, context.eval("foo('☃')").encoding

      ascii = "foo('hello')".encode('US-ASCII')
      result = context.eval(ascii)
      assert_equal "¶hello", result
      assert_equal utf8, result.encoding

      assert_raise Encoding::UndefinedConversionError do
        binary = "\xde\xad\xbe\xef".force_encoding("BINARY")
        context.eval(binary)
      end
    end
  end

  def test_compile
    context = ExecJS.compile("foo = function() { return \"bar\"; }")
    assert_equal "bar", context.exec("return foo()")
    assert_equal "bar", context.eval("foo()")
    assert_equal "bar", context.call("foo")
  end

  def test_this_is_global_scope
    assert_equal true, ExecJS.eval("this === (function() {return this})()")
    assert_equal true, ExecJS.exec("return this === (function() {return this})()")
  end

  def test_commonjs_vars_are_undefined
    assert ExecJS.eval("typeof module == 'undefined'")
    assert ExecJS.eval("typeof exports == 'undefined'")
    assert ExecJS.eval("typeof require == 'undefined'")
  end

  def test_console_is_undefined
    assert ExecJS.eval("typeof console == 'undefined'")
  end

  def test_compile_large_scripts
    body = "var foo = 'bar';\n" * 100_000
    assert ExecJS.exec("function foo() {\n#{body}\n};\nreturn true")
  end

  def test_syntax_error
    assert_raise ExecJS::RuntimeError do
      ExecJS.exec(")")
    end
  end

  def test_thrown_exception
    assert_raise ExecJS::ProgramError do
      ExecJS.exec("throw 'hello'")
    end
  end

  def test_coffeescript
    require "open-uri"
    assert source = open("http://jashkenas.github.com/coffee-script/extras/coffee-script.js").read
    context = ExecJS.compile(source)
    assert_equal 64, context.call("CoffeeScript.eval", "((x) -> x * x)(8)")
  end

  def test_json_encode
    context = ExecJS::ExternalRuntime::Context.new("foo")
    assert_equal '"foobar"', context.send(:json_encode, "foobar")
    assert_equal '{"foo":"bar"}', context.send(:json_encode, { "foo" => "bar" })
  end
end
