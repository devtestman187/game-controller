/// The tester guide as published (`site/index.html`, m13.4 tester-guide): every
/// link on it opens a page this repo ships in `site/`, or an address a doc
/// names, so a family following it never meets a dead link. And the pictures
/// come first, above the setup steps, each with its own caption and alt text.
///
/// The addresses are the ones the docs give: docs/release.md (the site, the
/// TestFlight public link, the testers group, both Play testing pages),
/// docs/store-listing.md (the GitHub Release with the Windows zip) and
/// docs/decisions.md (the contact email). A new link means a new line in
/// [knownLinks] and somewhere to check it.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The published pages: this package sits one folder inside the repo.
const siteDir = '../site';

/// The addresses the guide may link to, each with where it is written down.
const knownLinks = <String, String>{
  'https://devtestman187.github.io/game-controller/': 'docs/release.md, the site',
  'https://devtestman187.github.io/game-controller/privacy.html': 'docs/release.md, the site',
  'https://testflight.apple.com/join/afaU2DHU': 'docs/release.md, the TestFlight public link',
  'https://groups.google.com/g/thumb-party-testers': 'docs/release.md, the testers group',
  'https://play.google.com/apps/testing/com.thumbparty.app': 'docs/release.md, the phone app on Play testing',
  'https://play.google.com/apps/testing/com.thumbparty.tv': 'docs/release.md, the TV app on Play testing',
  'https://github.com/devtestman187/game-controller/releases/latest': 'docs/store-listing.md, the Windows zip',
};

/// Who testers write to (docs/decisions.md).
const knownEmail = 'mrman187@gmail.com';

/// The most a guide's picture row may hold, and the fewest.
const shotCounts = (min: 4, max: 6);

void main() {
  late String page;

  setUpAll(() => page = File('$siteDir/index.html').readAsStringSync());

  /// Every `href` and `src` on the page, in the order they appear.
  List<String> links() => [for (final m in RegExp(r'\b(?:href|src)="([^"]*)"').allMatches(page)) m.group(1)!];

  test('every link opens a page in site/ or an address the docs name', () {
    expect(links(), isNotEmpty);
    for (final link in links()) {
      if (link.startsWith('#')) {
        // A jump within the page: the target has to be there.
        final id = link.substring(1);
        expect(page.contains('id="$id"'), isTrue, reason: '"$link" jumps to an id the page has not got');
      } else if (link.startsWith('mailto:')) {
        expect(link.substring(7).split('?').first, knownEmail, reason: '"$link" writes to an address no doc names');
      } else if (link.contains('://')) {
        expect(knownLinks, contains(link), reason: '"$link" is not in knownLinks: add it with the doc that names it');
      } else {
        final file = File('$siteDir/${link.split('#').first}');
        expect(file.existsSync(), isTrue, reason: '"$link" is not a file in $siteDir/');
      }
    }
  });

  test('the pictures come before the setup steps, each captioned and described', () {
    final figures = RegExp(r'<figure\b.*?</figure>', dotAll: true).allMatches(page).toList();
    expect(figures.length, inInclusiveRange(shotCounts.min, shotCounts.max));
    for (final figure in figures) {
      final html = figure.group(0)!;
      final image = RegExp(r'<img\b[^>]*\bsrc="(shots/[^"]+)"[^>]*\balt="([^"]*)"').firstMatch(html);
      expect(image, isNotNull, reason: 'a picture has no src in shots/ and alt text: $html');
      expect(image!.group(2), isNotEmpty, reason: '${image.group(1)} has no alt text');
      final caption = RegExp(r'<figcaption>(.*?)</figcaption>', dotAll: true).firstMatch(html);
      expect(caption, isNotNull, reason: '${image.group(1)} has no caption');
      final words = caption!.group(1)!.trim();
      expect(words, isNotEmpty, reason: '${image.group(1)} has an empty caption');
      expect(words, isNot(contains('\n')), reason: '${image.group(1)} has a caption over more than one line');
    }
    // The pictures are the first thing a reader meets, before the steps.
    final firstHeading = page.indexOf('<h2');
    expect(figures.first.start, lessThan(firstHeading), reason: 'the pictures come after a setup step');
  });
}
