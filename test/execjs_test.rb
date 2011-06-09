require "test/unit"
require "execjs"

begin
  require "execjs"
  ExecJS.runtime
rescue ExecJS::RuntimeUnavailable => e
  warn e
  exit 2
end
