import 'dart:io';
import 'dart:math' as math;

class CalcException implements Exception {
  final String message;
  CalcException(this.message);
  @override
  String toString() => message;
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
      if (n == null) throw CalcException("Invalid number '${src.substring(start, pos)}'");
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
Operators : +  -  *  /  %  ^  ( )
Constants : pi, e, ans (last result)
Functions : sqrt() abs() sin() cos() tan() ln() log()
Commands  : history, help, clear, exit
Example   : 2 * (3 + 4) ^ 2 - sqrt(16)
''');
}

void main(List<String> args) {
  final history = <String>[];
  var ans = 0.0;

  // One-shot mode: dart run bin/calculator.dart "2+2"
  if (args.isNotEmpty) {
    try {
      print(format(Parser(args.join(' '), ans).parse()));
    } on CalcException catch (e) {
      stderr.writeln('Error: $e');
      exit(1);
    }
    return;
  }

  print('Dart CLI Calculator — type "help" for usage, "exit" to quit.');
  while (true) {
    stdout.write('> ');
    final line = stdin.readLineSync()?.trim();
    if (line == null) break;
    if (line.isEmpty) continue;

    switch (line.toLowerCase()) {
      case 'exit':
      case 'quit':
        print('Goodbye!');
        return;
      case 'help':
        printHelp();
        continue;
      case 'clear':
        history.clear();
        ans = 0;
        print('History cleared.');
        continue;
      case 'history':
        if (history.isEmpty) print('(empty)');
        for (var i = 0; i < history.length; i++) {
          print('${i + 1}. ${history[i]}');
        }
        continue;
    }

    try {
      final result = Parser(line, ans).parse();
      ans = result;
      final out = format(result);
      history.add('$line = $out');
      print(out);
    } on CalcException catch (e) {
      print('Error: $e');
    }
  }
}
