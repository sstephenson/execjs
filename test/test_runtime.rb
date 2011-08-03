# -*- coding: utf-8 -*-
require "execjs_test"

class TestRuntime < Test::Unit::TestCase
  def setup
    @runtime = ExecJS::Runtimes.autodetect
  end

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
    assert_equal "☃", @runtime.exec('return "☃"')
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
    assert_equal "☃", @runtime.eval('"☃"')
    assert_equal "\\", @runtime.eval('"\\\\"')
  end

  if defined? Encoding
    def test_encoding
      utf8 = Encoding.find('UTF-8')

      assert_equal utf8, @runtime.exec("return 'hello'").encoding
      assert_equal utf8, @runtime.eval("'☃'").encoding

      ascii = "'hello'".encode('US-ASCII')
      result = @runtime.eval(ascii)
      assert_equal "hello", result
      assert_equal utf8, result.encoding

      assert_raise Encoding::UndefinedConversionError do
        binary = "\xde\xad\xbe\xef".force_encoding("BINARY")
        @runtime.eval(binary)
      end
    end

    def test_encoding_compile
      utf8 = Encoding.find('UTF-8')

      context = @runtime.compile("foo = function(v) { return '¶' + v; }".encode("ISO8859-15"))

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
    context = @runtime.compile("foo = function() { return \"bar\"; }")
    assert_equal "bar", context.exec("return foo()")
    assert_equal "bar", context.eval("foo()")
    assert_equal "bar", context.call("foo")
  end

  def test_this_is_global_scope
    assert_equal true, @runtime.eval("this === (function() {return this})()")
    assert_equal true, @runtime.exec("return this === (function() {return this})()")
  end

  def test_compile_large_scripts
    body = "var foo = 'bar';\n" * 100_000
    assert @runtime.exec("function foo() {\n#{body}\n};\nreturn true")
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
  
  def test_simple_unbox
    [
      [{},"{}"], [{'foo'=>'bar'}, "{foo:'bar'}"],
      [[],"[]"], [[1,2,3],"[1,2,3]"]
    ].each do |expected,source|
      assert_equal expected, @runtime.eval(source)
    end
  end
  
  def test_nested_unbox
    [
      [{'foo'=>{}}, "{foo:{}}"], [{'foo'=>[]}, "{foo:[]}"],
      [{'foo'=>{'bar'=>{}}}, "{foo:{bar:{}}}"], [{'foo'=>[[1,{}]]}, "{foo:[[1,{}]]}"],
      [[{}],"[{}]"], [[[]],"[[]]"],
      [[{},[[[],{}]]],"[{},[[[],{}]]]"], [[[]],"[[]]"],
      [{'foo'=>{}}, "{f:function(){},foo:{g:function(){}}}"]
    ].each do |expected,source|
      assert_equal expected, @runtime.eval(source)
    end
  end
  
end
