# -*- coding: utf-8 -*-
require "minitest/autorun"
require "execjs/module"
require "json"

begin
  require "execjs"
rescue ExecJS::RuntimeUnavailable => e
  warn e
  exit 2
end

if defined? Minitest::Test
  Test = Minitest::Test
elsif defined? MiniTest::Unit::TestCase
  Test = MiniTest::Unit::TestCase
end

class TestExecJS < Test
  def test_runtime_available
    runtime = ExecJS::ExternalRuntime.new(command: "nonexistent")
    assert !runtime.available?

    runtime = ExecJS::ExternalRuntime.new(command: "ruby")
    assert runtime.available?
  end

  def test_runtime_assignment
    original_runtime = ExecJS.runtime
    runtime = ExecJS::ExternalRuntime.new(command: "nonexistent")
    assert_raises(ExecJS::RuntimeUnavailable) { ExecJS.runtime = runtime }
    assert_equal original_runtime, ExecJS.runtime

    runtime = ExecJS::ExternalRuntime.new(command: "ruby")
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

  {
    "function() {}" => nil,
    "0" => 0,
    "null" => nil,
    "undefined" => nil,
    "true" => true,
    "false" => false,
    "[1, 2]" => [1, 2],
    "[1, function() {}]" => [1, nil],
    "'hello'" => "hello",
    "'red yellow blue'.split(' ')" => ["red", "yellow", "blue"],
    "{a:1,b:2}" => {"a"=>1,"b"=>2},
    "{a:true,b:function (){}}" => {"a"=>true},
    "'café'" => "café",
    '"☃"' => "☃",
    '"\u2603"' => "☃",
    "'\u{1f604}'".encode("UTF-8") => "\u{1f604}".encode("UTF-8"), # Smiling emoji
    "'\u{1f1fa}\u{1f1f8}'".encode("UTF-8") => "\u{1f1fa}\u{1f1f8}".encode("UTF-8"), # US flag
    '"\\\\"' => "\\"
  }.each_with_index do |(input, output), index|
    define_method("test_exec_string_#{index}") do
      assert_equal output, ExecJS.exec("return #{input}")
    end

    define_method("test_eval_string_#{index}") do
      assert_equal output, ExecJS.eval(input)
    end

    define_method("test_compile_return_string_#{index}") do
      context = ExecJS.compile("var a = #{input};")
      assert_equal output, context.eval("a")
    end

    define_method("test_compile_call_string_#{index}") do
      context = ExecJS.compile("function a() { return #{input}; }")
      assert_equal output, context.call("a")
    end
  end

  [
    nil,
    true,
    false,
    1,
    3.14,
    "hello",
    "\\",
    "café",
    "☃",
    "\u{1f604}".encode("UTF-8"), # Smiling emoji
    "\u{1f1fa}\u{1f1f8}".encode("UTF-8"), # US flag
    [1, 2, 3],
    [1, [2, 3]],
    [1, [2, [3]]],
    ["red", "yellow", "blue"],
    { "a" => 1, "b" => 2},
    { "a" => 1, "b" => [2, 3]},
    { "a" => true }
  ].each_with_index do |value, index|
    json_value = JSON.generate(value, quirks_mode: true)

    define_method("test_json_value_#{index}") do
      assert_equal value, JSON.parse(json_value, quirks_mode: true)
    end

    define_method("test_exec_value_#{index}") do
      assert_equal value, ExecJS.exec("return #{json_value}")
    end

    define_method("test_eval_value_#{index}") do
      assert_equal value, ExecJS.eval("#{json_value}")
    end

    define_method("test_strinigfy_value_#{index}") do
      context = ExecJS.compile("function json(obj) { return JSON.stringify(obj); }")
      assert_equal json_value, context.call("json", value)
    end

    define_method("test_call_value_#{index}") do
      context = ExecJS.compile("function id(obj) { return obj; }")
      assert_equal value, context.call("id", value)
    end
  end

  def test_eval_blank
    assert_nil ExecJS.eval("")
    assert_nil ExecJS.eval(" ")
    assert_nil ExecJS.eval("  ")
  end

  def test_exec_return
    assert_nil ExecJS.exec("return")
  end

  def test_exec_no_return
    assert_nil ExecJS.exec("1")
  end

  def test_encoding
    utf8 = Encoding.find('UTF-8')

    assert_equal utf8, ExecJS.exec("return 'hello'").encoding
    assert_equal utf8, ExecJS.eval("'☃'").encoding

    ascii = "'hello'".encode('US-ASCII')
    result = ExecJS.eval(ascii)
    assert_equal "hello", result
    assert_equal utf8, result.encoding

    assert_raises Encoding::UndefinedConversionError do
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

    assert_raises Encoding::UndefinedConversionError do
      binary = "\xde\xad\xbe\xef".force_encoding("BINARY")
      context.eval(binary)
    end
  end

  def test_surrogate_pairs
    # Smiling emoji
    str = "\u{1f604}".encode("UTF-8")
    assert_equal 2, ExecJS.eval("'#{str}'.length")
    assert_equal str, ExecJS.eval("'#{str}'")

    # US flag emoji
    str = "\u{1f1fa}\u{1f1f8}".encode("UTF-8")
    assert_equal 4, ExecJS.eval("'#{str}'.length")
    assert_equal str, ExecJS.eval("'#{str}'")
  end

  def test_compile_anonymous_function
    context = ExecJS.compile("foo = function() { return \"bar\"; }")
    assert_equal "bar", context.exec("return foo()")
    assert_equal "bar", context.eval("foo()")
    assert_equal "bar", context.call("foo")
  end

  def test_compile_named_function
    context = ExecJS.compile("function foo() { return \"bar\"; }")
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

  def test_timers_are_undefined
    assert ExecJS.eval("typeof setTimeout == 'undefined'")
    assert ExecJS.eval("typeof setInterval == 'undefined'")
    assert ExecJS.eval("typeof clearTimeout == 'undefined'")
    assert ExecJS.eval("typeof clearInterval == 'undefined'")
    assert ExecJS.eval("typeof setImmediate == 'undefined'")
    assert ExecJS.eval("typeof clearImmediate == 'undefined'")
  end

  def test_compile_large_scripts
    body = "var foo = 'bar';\n" * 100_000
    assert ExecJS.exec("function foo() {\n#{body}\n};\nreturn true")
  end

  def test_exec_syntax_error
    assert_raises ExecJS::RuntimeError do
      ExecJS.exec(")")
    end
  end

  def test_eval_syntax_error
    assert_raises ExecJS::RuntimeError do
      ExecJS.eval(")")
    end
  end

  def test_compile_syntax_error
    assert_raises ExecJS::RuntimeError do
      ExecJS.compile(")")
    end
  end

  def test_exec_thrown_exception
    assert_raises ExecJS::ProgramError do
      ExecJS.exec("throw 'hello'")
    end
  end

  def test_eval_thrown_exception
    assert_raises ExecJS::ProgramError do
      ExecJS.exec("throw 'hello'")
    end
  end

  def test_compile_thrown_exception
    assert_raises ExecJS::ProgramError do
      ExecJS.exec("throw 'hello'")
    end
  end

  def test_coffeescript
    assert source = File.read(File.expand_path("../fixtures/coffee-script.js", __FILE__))
    context = ExecJS.compile(source)
    assert_equal 64, context.call("CoffeeScript.eval", "((x) -> x * x)(8)")
  end
end
