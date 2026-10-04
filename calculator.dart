import 'dart:io';
import 'dart:math' as math;

class CalcException implements Exception {
  final String message;
  CalcException(this.message);
  @override
  String toString() => message;
}

/// ANSI Escape codes for adding colors to terminal output
class Ansi {
  static const reset = '\x1B[0m';
  static const bold = '\x1B[1m';
  static const red = '\x1B[31m';
  static const green = '\x1B[32m';
  static const yellow = '\x1B[33m';
  static const blue = '\x1B[34m';
  static const magenta = '\x1B[35m';
  static const cyan = '\x1B[36m';
  static const gray = '\x1B[90m';
  static const clearScreen = '\x1B[2J\x1B[H';
}

/// Recursive-descent parser: + - * / % ^, parentheses, unary minus,
/// constants (pi, e, ans) and functions (sqrt, abs, sin, cos, tan, ln, log).
class Parser {
  final String src;
  final double ans;
  int pos = 0;

  Parser(this.src, this.ans);

  double parse() {
    final v = _expr();
    _skip();
    if (pos < src.length) {
      throw CalcException("Unexpected '${src[pos]}' at position ${pos + 1}");
    }
    return v;
  }

  void _skip() {
    while (pos < src.length && src[pos] == ' ') {
      pos++;
    }
  }

  bool _eat(String c) {
    _skip();
    if (pos < src.length && src[pos] == c) {
      pos++;
      return true;
    }
    return false;
  }

  double _expr() {
    var v = _term();
    while (true) {
      if (_eat('+')) {
        v += _term();
      } else if (_eat('-')) {
        v -= _term();
      } else {
        return v;
      }
    }
  }

  double _term() {
    var v = _unary();
    while (true) {
      if (_eat('*')) {
        v *= _unary();
      } else if (_eat('/')) {
        final d = _unary();
        if (d == 0) throw CalcException('Division by zero');
        v /= d;
      } else if (_eat('%')) {
        final d = _unary();
        if (d == 0) throw CalcException('Modulo by zero');
        v %= d;
      } else {
        return v;
      }
    }
  }

  double _unary() {
    if (_eat('-')) return -_unary();
    if (_eat('+')) return _unary();
    return _power();
  }

  double _power() {
    final base = _primary();
    if (_eat('^')) {
      return math.pow(base, _unary()).toDouble(); // right-associative
    }
    return base;
  }

  double _primary() {
    _skip();
    if (pos >= src.length) throw CalcException('Unexpected end of expression');

    if (_eat('(')) {
      final v = _expr();
      if (!_eat(')')) throw CalcException("Missing closing ')'");
      return v;
    }

    final start = pos;
    if (RegExp(r'[0-9.]').hasMatch(src[pos])) {
      while (pos < src.length && RegExp(r'[0-9.]').hasMatch(src[pos])) {
        pos++;
      }
      final n = double.tryParse(src.substring(start, pos));
      if (n == null)
        throw CalcException("Invalid number '${src.substring(start, pos)}'");
      return n;
    }

    if (RegExp(r'[a-zA-Z]').hasMatch(src[pos])) {
      while (pos < src.length && RegExp(r'[a-zA-Z]').hasMatch(src[pos])) {
        pos++;
      }
      final name = src.substring(start, pos).toLowerCase();
      switch (name) {
        case 'pi':
          return math.pi;
        case 'e':
          return math.e;
        case 'ans':
          return ans;
      }
      if (!_eat('(')) throw CalcException("Unknown name '$name'");
      final arg = _expr();
      if (!_eat(')')) throw CalcException("Missing closing ')'");
      switch (name) {
        case 'sqrt':
          if (arg < 0) throw CalcException('sqrt of a negative number');
          return math.sqrt(arg);
        case 'abs':
          return arg.abs();
        case 'sin':
          return math.sin(arg);
        case 'cos':
          return math.cos(arg);
        case 'tan':
          return math.tan(arg);
        case 'ln':
          if (arg <= 0) throw CalcException('ln needs a positive number');
          return math.log(arg);
        case 'log':
          if (arg <= 0) throw CalcException('log needs a positive number');
          return math.log(arg) / math.ln10;
        default:
          throw CalcException("Unknown function '$name'");
      }
    }

    throw CalcException("Unexpected '${src[pos]}' at position ${pos + 1}");
  }
}

String format(double v) {
  if (v.isNaN || v.isInfinite) return v.toString();
  if (v == v.truncateToDouble() && v.abs() < 1e15) return v.toInt().toString();
  return double.parse(v.toStringAsPrecision(12)).toString();
}

void printHelp() {
  print('''
${Ansi.cyan}${Ansi.bold}=== Dart CLI Calculator ===${Ansi.reset}

  ${Ansi.bold}Operators:${Ansi.reset} ${Ansi.yellow}+  -  *  /  %  ^  ( )${Ansi.reset}
  ${Ansi.bold}Constants:${Ansi.reset} ${Ansi.magenta}pi${Ansi.reset}, ${Ansi.magenta}e${Ansi.reset}, ${Ansi.magenta}ans${Ansi.reset} (last result)
  ${Ansi.bold}Functions:${Ansi.reset} ${Ansi.blue}sqrt() abs() sin() cos() tan() ln() log()${Ansi.reset}
  ${Ansi.bold}Commands: ${Ansi.reset} ${Ansi.green}history, help, clear, exit${Ansi.reset}
  ${Ansi.bold}Example:  ${Ansi.reset} ${Ansi.gray}2 * (3 + 4) ^ 2 - sqrt(16)${Ansi.reset}
''');
}

void printBanner() {
  print(
    Ansi.clearScreen +
        '''
${Ansi.cyan}${Ansi.bold}    ____             __     ______      __    
   / __ \\____ ______/ /_   / ____/___ _/ /____
  / / / / __ `/ ___/ __/  / /   / __ `/ / ___/
 / /_/ / /_/ / /  / /_   / /___/ /_/ / / /__  
/_____/\\__,_/_/   \\__/   \\____/\\__,_/_/\\___/  
${Ansi.reset}
  ${Ansi.gray}Type ${Ansi.green}"help"${Ansi.gray} for usage, or ${Ansi.green}"exit"${Ansi.gray} to quit.${Ansi.reset}
''',
  );
}

void main(List<String> args) {
  final history = <String>[];
  var ans = 0.0;

  // One-shot mode: dart run bin/calculator.dart "2+2"
  if (args.isNotEmpty) {
    try {
      print(format(Parser(args.join(' '), ans).parse()));
    } on CalcException catch (e) {
      stderr.writeln('${Ansi.red}Error: $e${Ansi.reset}');
      exit(1);
    }
    return;
  }

  printBanner();

  while (true) {
    stdout.write('${Ansi.cyan}${Ansi.bold}calc>${Ansi.reset} ');
    final line = stdin.readLineSync()?.trim();
    if (line == null) break;
    if (line.isEmpty) continue;

    switch (line.toLowerCase()) {
      case 'exit':
      case 'quit':
        print('${Ansi.green}Goodbye!${Ansi.reset}');
        return;
      case 'help':
        printHelp();
        continue;
      case 'clear':
        history.clear();
        ans = 0;
        print(Ansi.clearScreen);
        printBanner();
        continue;
      case 'history':
        if (history.isEmpty) {
          print('  ${Ansi.gray}(empty)${Ansi.reset}');
        } else {
          for (var i = 0; i < history.length; i++) {
            print('  ${Ansi.gray}${i + 1}.${Ansi.reset} ${history[i]}');
          }
        }
        continue;
    }

    try {
      final result = Parser(line, ans).parse();
      ans = result;
      final out = format(result);
      history.add('$line = $out');
      print(
        '  ${Ansi.gray}=${Ansi.reset} ${Ansi.green}${Ansi.bold}$out${Ansi.reset}\n',
      );
    } on CalcException catch (e) {
      print('  ${Ansi.red}Error: ${e.message}${Ansi.reset}\n');
    }
  }
}
