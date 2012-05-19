(function(program, execJS) { execJS(program) })(function(module, exports, require) {
#{source}
}, function(program) {
  var output, print = function(string) {
    process.stdout.write('' + string);
  };
  try {
    result = program();
    if (typeof result == 'undefined' && result !== null) {
      print('["ok"]');
    } else {
      try {
        print(JSON.stringify(['ok', result, null]));
      } catch (err) {
        print(JSON.stringify(['err', 'Cant\'t stringify result', err.stack]));
      }
    }
  } catch (err) {
    print(JSON.stringify(['err', err.message || '' + err, err.stack]));
  }
});
