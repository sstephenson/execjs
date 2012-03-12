# -*- coding: utf-8 -*-
require "test/unit"
require "execjs/module"

begin
  require "execjs"
rescue ExecJS::RuntimeUnavailable => e
  warn e
  exit 2
end

class TestDisabledRuntime < Test::Unit::TestCase
  attr_accessor :runtime

  def setup
    self.runtime = ExecJS.runtime
  end

  def test_exec_raises_error
    assert_raises(ExecJS::Error) {runtime.exec("Raise please.")}
  end

  def test_eval_raises_error
    assert_raises(ExecJS::Error) {runtime.eval("Raise please.")}
  end

  def test_compile_raises_error
    assert_raises(ExecJS::Error) {runtime.compile("Raise please.")}
  end

  def test_available
    assert runtime.available?
  end

  def test_name
    assert_equal "Disabled", runtime.name
  end
end
