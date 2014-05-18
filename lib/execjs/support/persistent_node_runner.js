var readline = require('readline');
var vm = require('vm');

var contexts = {}
var context = vm.createContext();

var rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

var print = function(string) {
  process.stdout.write('' + string + "\n");
};

var waitForInput = function () {
  rl.question('', function(input) {
    try {
      input = JSON.parse(input);

      if (input.length === 1) {
        if (input[0] in contexts) {
          delete contexts[input[0]];
        }
        print('["ok"]');
      } else {
        if (!(input[0] in contexts)) {
          contexts[input[0]] = vm.createContext();
        }

        var result = vm.runInContext(input[1], contexts[input[0]]);

        if (typeof result == 'undefined' && result !== null) {
          print('["ok"]');
        } else {
          try {
            print(JSON.stringify(['ok', result]));
          } catch (err) {
            print('["err"]');
          }
        }
      }
    } catch (err) {
      print(JSON.stringify(['err', '' + err]));
    }

    waitForInput();
  });
}

waitForInput();