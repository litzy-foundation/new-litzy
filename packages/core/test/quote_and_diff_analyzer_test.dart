// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:core/core.dart';
import 'package:test/test.dart';

String body(List<String> lines) => lines.join(TextTokens.lineFeed);

void main() {
  const analyzer = QuoteAndDiffAnalyzer();

  test('plain prose produces one text block', () {
    final analysis = analyzer.analyze(body(['hello', 'world']));
    expect(analysis.blocks, hasLength(1));
    expect(analysis.blocks.single, isA<TextBlock>());
    expect(analysis.freshText, 'hello${TextTokens.lineFeed}world');
    expect(analysis.maxQuoteLevel, 0);
  });

  test('quotes are split from fresh prose by citation level', () {
    final analysis = analyzer.analyze(
      body(['my answer', '${TextTokens.quoteMarker} his claim', 'still mine']),
    );
    expect(analysis.blocks, hasLength(3));
    final quote = analysis.blocks[1] as QuoteBlock;
    expect(quote.level, 1);
    expect(quote.unindented, 'his claim');
    expect(analysis.freshText, 'my answer${TextTokens.lineFeed}still mine');
  });

  test('nested quotes keep their levels', () {
    final analysis = analyzer.analyze(
      body([
        '${TextTokens.quoteMarker} level one',
        '${TextTokens.quoteMarker * 2} level two',
        '${TextTokens.quoteMarker} back to one',
      ]),
    );
    expect(
      analysis.blocks.whereType<QuoteBlock>().map((block) => block.level),
      [1, 2, 1],
    );
    expect(analysis.maxQuoteLevel, 2);
  });

  test('a complete patch is one diff block', () {
    final rawPatch = body([
      '--- a/kernel/sched/fair.c',
      '+++ b/kernel/sched/fair.c',
      '@@ -1,3 +1,4 @@',
      ' context line',
      '-removed line',
      '+added line',
    ]);
    final analysis = analyzer.analyze(
      body(['Fix included below.', '', ...rawPatch.split(TextTokens.lineFeed)]),
    );
    final diff = analysis.blocks.whereType<DiffBlock>().single;
    expect(diff.fileHeaders, [
      'a/kernel/sched/fair.c',
      'b/kernel/sched/fair.c',
    ]);
    expect(diff.hunkHeaderCount, 1);
    expect(diff.raw, contains('-removed line'));
    expect(analysis.freshText, 'Fix included below.');
    expect(analysis.patchText, contains('@@ -1,3 +1,4 @@'));
  });

  test('a patch inside a reply is detected after a quote', () {
    final analysis = analyzer.analyze(
      body([
        '${TextTokens.quoteMarker} previous discussion',
        '',
        'diff --git a/lib/x.dart b/lib/x.dart',
        'index 1111111..2222222 100644',
        '--- a/lib/x.dart',
        '+++ b/lib/x.dart',
        '@@ -5,7 +5,7 @@',
        '-old',
        '+new',
        '',
        'Done.',
      ]),
    );
    expect(analysis.blocks.whereType<DiffBlock>(), hasLength(1));
    expect(analysis.freshText, contains('Done.'));
    expect(analysis.maxQuoteLevel, 1);
  });

  test('multiple hunks are counted', () {
    final analysis = analyzer.analyze(
      body(['--- a/f.c', '+++ b/f.c', '@@ -1,2 +1,2 @@', '@@ -10,1 +10,1 @@']),
    );
    final diff = analysis.blocks.whereType<DiffBlock>().single;
    expect(diff.hunkHeaderCount, 2);
  });

  test('an empty body produces no blocks', () {
    expect(analyzer.analyze('').blocks, isEmpty);
  });
}
