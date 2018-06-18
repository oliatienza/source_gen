// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
import 'dart:async';

import 'package:build_test/build_test.dart';
import 'package:source_gen/builder.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

import 'src/comment_generator.dart';
import 'src/unformatted_code_generator.dart';

void main() {
  test('Simple Generator test', () {
    _generateTest(const CommentGenerator(forClasses: true, forLibrary: false),
        _testGenPartContent);
  });

  test('Bad generated source', () async {
    var srcs = _createPackageStub();
    var builder = new PartBuilder([const _BadOutputGenerator()], '.foo.dart');

    await testBuilder(builder, srcs,
        generateFor: new Set.from(['$_pkgName|lib/test_lib.dart']),
        outputs: {
          '$_pkgName|lib/test_lib.foo.dart':
              decodedMatches(contains('not valid code!')),
        });
  });

  test('Generate standalone output file', () async {
    var srcs = _createPackageStub();
    var builder = new LibraryBuilder(const CommentGenerator());
    await testBuilder(builder, srcs,
        generateFor: new Set.from(['$_pkgName|lib/test_lib.dart']),
        outputs: {
          '$_pkgName|lib/test_lib.g.dart': _testGenStandaloneContent,
        });
  });

  test('Generate standalone output file with custom header', () async {
    var srcs = _createPackageStub();
    var builder =
        new LibraryBuilder(const CommentGenerator(), header: _customHeader);
    await testBuilder(builder, srcs,
        generateFor: new Set.from(['$_pkgName|lib/test_lib.dart']),
        outputs: {
          '$_pkgName|lib/test_lib.g.dart':
              decodedMatches(startsWith('$_customHeader\n\n// ***'))
        });
  });

  test('LibraryBuilder omits header if provided an empty String', () async {
    var srcs = _createPackageStub();
    var builder = new LibraryBuilder(const CommentGenerator(), header: '');
    await testBuilder(builder, srcs,
        generateFor: new Set.from(['$_pkgName|lib/test_lib.dart']),
        outputs: {
          '$_pkgName|lib/test_lib.g.dart': decodedMatches(startsWith('// ***'))
        });
  });

  test('Expect no error when multiple generators used on nonstandalone builder',
      () async {
    expect(
        () => new PartBuilder(
            [const CommentGenerator(), const _LiteralGenerator()], '.foo.dart'),
        returnsNormally);
  });

  test('Allow no "library"  by default', () async {
    var sources = _createPackageStub(testLibContent: 'class A {}');
    var builder = new PartBuilder([const CommentGenerator()], '.foo.dart');

    await testBuilder(builder, sources,
        outputs: {'$_pkgName|lib/test_lib.foo.dart': _testGenNoLibrary});
  });

  test('Does not fail when there is no output', () async {
    var sources = _createPackageStub(testLibContent: 'class A {}');
    var builder = new PartBuilder(
        [const CommentGenerator(forClasses: false)], '.foo.dart');
    await testBuilder(builder, sources, outputs: {});
  });

  test('Use new part syntax when no library directive exists', () async {
    var sources = _createPackageStub(testLibContent: 'class A {}');
    var builder = new PartBuilder([const CommentGenerator()], '.foo.dart');
    await testBuilder(builder, sources,
        outputs: {'$_pkgName|lib/test_lib.foo.dart': _testGenNoLibrary});
  });

  test(
      'Simple Generator test for library',
      () => _generateTest(
          const CommentGenerator(forClasses: false, forLibrary: true),
          _testGenPartContentForLibrary));

  test(
      'Simple Generator test for classes and library',
      () => _generateTest(
          const CommentGenerator(forClasses: true, forLibrary: true),
          _testGenPartContentForClassesAndLibrary));

  test('null result produces no generated parts', () async {
    var srcs = _createPackageStub();
    var builder = _unformattedLiteral();
    await testBuilder(builder, srcs, outputs: {});
  });

  test('handle generator errors well', () async {
    var srcs = _createPackageStub(testLibContent: _testLibContentWithError);
    var builder = new PartBuilder([const CommentGenerator()], '.foo.dart');
    await testBuilder(builder, srcs,
        generateFor: new Set.from(['$_pkgName|lib/test_lib.dart']),
        outputs: {
          '$_pkgName|lib/test_lib.foo.dart': _testGenPartContentError,
        });
  });

  test('warns when a non-standalone builder does not see "part"', () async {
    var srcs = _createPackageStub(testLibContent: _testLibContentNoPart);
    var builder = new PartBuilder([const CommentGenerator()], '.foo.dart');
    var logs = <String>[];
    await testBuilder(
      builder,
      srcs,
      onLog: (log) {
        logs.add(log.message);
      },
    );
    expect(logs, ['Missing "part \'test_lib.foo.dart\';".']);
  });

  test('generator with an empty result creates no outputs', () async {
    var srcs = _createPackageStub(testLibContent: _testLibContentNoPart);
    var builder = _unformattedLiteral('');
    await testBuilder(
      builder,
      srcs,
      outputs: {},
    );
  });

  test('generator with whitespace-only result has no outputs', () async {
    var srcs = _createPackageStub(testLibContent: _testLibContentNoPart);
    var builder = _unformattedLiteral('\n  \n');
    await testBuilder(
      builder,
      srcs,
      outputs: {},
    );
  });

  test('generator result with wrapping whitespace is trimmed', () async {
    var srcs = _createPackageStub(testLibContent: _testLibContent);
    var builder = _unformattedLiteral('\n// hello\n');
    await testBuilder(
      builder,
      srcs,
      outputs: {
        '$_pkgName|lib/test_lib.foo.dart': _whitespaceTrimmed,
      },
    );
  });

  test('defaults to formatting generated code with the DartFormatter',
      () async {
    await testBuilder(
        new PartBuilder([const UnformattedCodeGenerator()], '.foo.dart'),
        {'$_pkgName|lib/a.dart': 'library a; part "a.part.dart";'},
        generateFor: new Set.from(['$_pkgName|lib/a.dart']),
        outputs: {
          '$_pkgName|lib/a.foo.dart':
              decodedMatches(contains(UnformattedCodeGenerator.formattedCode)),
        });
  });

  test('PartBuilder uses a custom header when provided', () async {
    await testBuilder(
        new PartBuilder([const UnformattedCodeGenerator()], '.foo.dart',
            header: _customHeader),
        {'$_pkgName|lib/a.dart': 'library a; part "a.part.dart";'},
        generateFor: new Set.from(['$_pkgName|lib/a.dart']),
        outputs: {
          '$_pkgName|lib/a.foo.dart':
              decodedMatches(startsWith('$_customHeader\n\npart of')),
        });
  });

  test('PartBuilder includes no header when `header` is empty', () async {
    await testBuilder(
        new PartBuilder([const UnformattedCodeGenerator()], '.foo.dart',
            header: ''),
        {'$_pkgName|lib/a.dart': 'library a; part "a.part.dart";'},
        generateFor: new Set.from(['$_pkgName|lib/a.dart']),
        outputs: {
          '$_pkgName|lib/a.foo.dart': decodedMatches(startsWith('part of')),
        });
  });

  group('SharedPartBuilder', () {
    test('warns about missing part', () async {
      var srcs = _createPackageStub(testLibContent: _testLibContentNoPart);
      var builder =
          new SharedPartBuilder([const CommentGenerator()], 'comment');
      var logs = <String>[];
      await testBuilder(
        builder,
        srcs,
        onLog: (log) {
          logs.add(log.message);
        },
      );
      expect(logs, ['Missing "part \'test_lib.g.dart\';".']);
    });

    test('outputs <partId>.g.part files', () async {
      await testBuilder(
          new SharedPartBuilder(
            [const UnformattedCodeGenerator()],
            'foo',
          ),
          {'$_pkgName|lib/a.dart': 'library a; part "a.g.dart";'},
          generateFor: new Set.from(['$_pkgName|lib/a.dart']),
          outputs: {
            '$_pkgName|lib/a.foo.g.part': decodedMatches(
                contains(UnformattedCodeGenerator.formattedCode)),
          });
    });

    test('does not output files which contain `part of`', () async {
      await testBuilder(
          new SharedPartBuilder(
            [const UnformattedCodeGenerator()],
            'foo',
          ),
          {'$_pkgName|lib/a.dart': 'library a; part "a.g.dart";'},
          generateFor: new Set.from(['$_pkgName|lib/a.dart']),
          outputs: {
            '$_pkgName|lib/a.foo.g.part':
                decodedMatches(isNot(contains('part of'))),
          });
    });

    group('constructor', () {
      for (var entry in {
        'starts with `.`': '.foo',
        'ends with `.`': 'foo.',
        'is empty': '',
        'contains whitespace': 'coo bob',
        'contains symbols': '%oops',
        'contains . in the middle': 'cool.thing'
      }.entries) {
        test('throws if the partId ${entry.key}', () async {
          expect(
              () => new SharedPartBuilder(
                    [const UnformattedCodeGenerator()],
                    entry.value,
                  ),
              throwsArgumentError);
        });
      }
    });
  });

  group('CombiningBuilder', () {
    test('CombiningBuilder includes a generated code header', () async {
      await testBuilder(
          new CombiningBuilder(),
          {
            '$_pkgName|lib/a.dart': 'library a; part "a.g.dart";',
            '$_pkgName|lib/a.foo.g.part': 'some generated content'
          },
          generateFor: new Set.from(['$_pkgName|lib/a.dart']),
          outputs: {
            '$_pkgName|lib/a.g.dart': decodedMatches(
                startsWith('// GENERATED CODE - DO NOT MODIFY BY HAND')),
          });
    });

    test('outputs `.g.dart` files', () async {
      await testBuilder(
          new CombiningBuilder(),
          {
            '$_pkgName|lib/a.dart': 'library a; part "a.g.dart";',
            '$_pkgName|lib/a.foo.g.part': 'some generated content'
          },
          generateFor: new Set.from(['$_pkgName|lib/a.dart']),
          outputs: {
            '$_pkgName|lib/a.g.dart':
                decodedMatches(contains('some generated content')),
          });
    });

    test('outputs contain `part of`', () async {
      await testBuilder(
          new CombiningBuilder(),
          {
            '$_pkgName|lib/a.dart': 'library a; part "a.g.dart";',
            '$_pkgName|lib/a.foo.g.part': 'some generated content'
          },
          generateFor: new Set.from(['$_pkgName|lib/a.dart']),
          outputs: {
            '$_pkgName|lib/a.g.dart': decodedMatches(contains('part of')),
          });
    });

    test('joins part files', () async {
      await testBuilder(
          new CombiningBuilder(),
          {
            '$_pkgName|lib/a.dart': 'library a; part "a.g.dart";',
            '$_pkgName|lib/a.foo.g.part': 'some generated content',
            '$_pkgName|lib/a.bar.g.part': 'more generated content',
          },
          generateFor: new Set.from(['$_pkgName|lib/a.dart']),
          outputs: {
            '$_pkgName|lib/a.g.dart': decodedMatches(
                contains('some generated content\nmore generated content')),
          });
    });

    test('joins only associated part files', () async {
      await testBuilder(
          new CombiningBuilder(),
          {
            '$_pkgName|lib/a.dart': 'library a; part "a.g.dart";',
            '$_pkgName|lib/a.foo.g.part': 'some generated content',
            '$_pkgName|lib/a.bar.g.part': 'more generated content',
            '$_pkgName|lib/a.bar.other.g.part': 'skipped generated content',
          },
          generateFor: new Set.from(['$_pkgName|lib/a.dart']),
          outputs: {
            '$_pkgName|lib/a.g.dart': decodedMatches(
                contains('some generated content\nmore generated content')),
          });
    });

    test('outputs nothing if no part files are found', () async {
      await testBuilder(
          new CombiningBuilder(),
          {
            '$_pkgName|lib/a.dart': 'library a; part "a.g.dart";',
          },
          generateFor: new Set.from(['$_pkgName|lib/a.dart']),
          outputs: {});
    });
  });

  test('can skip formatting with a trivial lambda', () async {
    await testBuilder(
        new PartBuilder([const UnformattedCodeGenerator()], '.foo.dart',
            formatOutput: (s) => s),
        {'$_pkgName|lib/a.dart': 'library a; part "a.part.dart";'},
        generateFor: new Set.from(['$_pkgName|lib/a.dart']),
        outputs: {
          '$_pkgName|lib/a.foo.dart': decodedMatches(
              contains(UnformattedCodeGenerator.unformattedCode)),
        });
  });

  test('can pass a custom formatter with formatOutput', () async {
    var customOutput = 'final String hello = "hello";';
    await testBuilder(
        new PartBuilder([const UnformattedCodeGenerator()], '.foo.dart',
            formatOutput: (_) => customOutput),
        {'$_pkgName|lib/a.dart': 'library a; part "a.part.dart";'},
        generateFor: new Set.from(['$_pkgName|lib/a.dart']),
        outputs: {
          '$_pkgName|lib/a.foo.dart': decodedMatches(contains(customOutput)),
        });
  });

  test('Should have a readable toString() message for builders', () {
    final builder = new LibraryBuilder(const _LiteralGenerator());
    expect(builder.toString(), 'Generating .g.dart: _LiteralGenerator');

    final builders = new PartBuilder([
      const _LiteralGenerator(),
      const _LiteralGenerator(),
    ], '.foo.dart');
    expect(builders.toString(),
        'Generating .foo.dart: _LiteralGenerator, _LiteralGenerator');
  });
}

Future _generateTest(CommentGenerator gen, String expectedContent) async {
  var srcs = _createPackageStub();
  var builder = new PartBuilder([gen], '.foo.dart');

  await testBuilder(builder, srcs,
      generateFor: new Set.from(['$_pkgName|lib/test_lib.dart']),
      outputs: {
        '$_pkgName|lib/test_lib.foo.dart': decodedMatches(expectedContent),
      },
      onLog: (log) => fail('Unexpected log message: ${log.message}'));
}

Map<String, String> _createPackageStub(
    {String testLibContent, String testLibPartContent}) {
  return {
    '$_pkgName|lib/test_lib.dart': testLibContent ?? _testLibContent,
    '$_pkgName|lib/test_lib.foo.dart':
        testLibPartContent ?? _testLibPartContent,
  };
}

PartBuilder _unformattedLiteral([String content]) =>
    new PartBuilder([new _LiteralGenerator(content)], '.foo.dart',
        formatOutput: (s) => s);

/// Returns the [String] provided in the constructor, or `null`.
class _LiteralGenerator extends Generator {
  final String _content;

  const _LiteralGenerator([this._content]);

  @override
  String generate(_, __) => _content;
}

class _BadOutputGenerator extends Generator {
  const _BadOutputGenerator();

  @override
  String generate(_, __) => 'not valid code!';
}

final _customHeader = '// Copyright 1979';

const _pkgName = 'pkg';

const _testLibContent = r'''
library test_lib;
part 'test_lib.foo.dart';
final int foo = 42;
class Person { }
''';

const _testLibContentNoPart = r'''
library test_lib;
final int foo = 42;
class Person { }
''';

const _testLibContentWithError = r'''
library test_lib;
part 'test_lib.g.dart';
class MyError { }
class MyGoodError { }
''';

const _testLibPartContent = r'''
part of test_lib;
final int bar = 42;
class Customer { }
''';

const _testGenPartContent = r'''// GENERATED CODE - DO NOT MODIFY BY HAND

part of test_lib;

// **************************************************************************
// CommentGenerator
// **************************************************************************

// Code for "class Person"
// Code for "class Customer"
''';

const _testGenPartContentForLibrary =
    r'''// GENERATED CODE - DO NOT MODIFY BY HAND

part of test_lib;

// **************************************************************************
// CommentGenerator
// **************************************************************************

// Code for "test_lib"
''';

const _testGenStandaloneContent = r'''// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// CommentGenerator
// **************************************************************************

// Code for "class Person"
// Code for "class Customer"
''';

const _testGenPartContentForClassesAndLibrary =
    r'''// GENERATED CODE - DO NOT MODIFY BY HAND

part of test_lib;

// **************************************************************************
// CommentGenerator
// **************************************************************************

// Code for "test_lib"
// Code for "class Person"
// Code for "class Customer"
''';

const _testGenPartContentError = r'''// GENERATED CODE - DO NOT MODIFY BY HAND

part of test_lib;

// **************************************************************************
// CommentGenerator
// **************************************************************************

// Error: Don't use classes with the word 'Error' in the name
//        package:pkg/test_lib.dart:4:7
//        class MyGoodError { }
//              ^^^^^^^^^^^
// TODO: Rename MyGoodError to something else.
''';

const _testGenNoLibrary = r'''// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'test_lib.dart';

// **************************************************************************
// CommentGenerator
// **************************************************************************

// Code for "class A"
''';

const _whitespaceTrimmed = r'''// GENERATED CODE - DO NOT MODIFY BY HAND

part of test_lib;

// **************************************************************************
// _LiteralGenerator
// **************************************************************************

// hello
''';