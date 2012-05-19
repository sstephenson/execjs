(function(program, execJS) { execJS(program) })(function() {
#{encoded_source}
}, function(program) {
  #{json2_source}
  var output, print = function(string) {
    WScript.Echo(string);
  };
  result = program();
  if (typeof result == 'undefined' && result !== null) {
    print('["ok"]');
  } else {
    try {
      print(JSON.stringify(['ok', result]));
    } catch (err) {
      print(JSON.stringify(['err', 'Cant\'t stringify result']));
    }
  }
});
