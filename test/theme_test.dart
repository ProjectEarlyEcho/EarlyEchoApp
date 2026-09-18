import 'package:earlyecho/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final themes = {
    'light': EarlyEchoTheme.lightTheme,
    'dark': EarlyEchoTheme.darkTheme,
  };

  for (final entry in themes.entries) {
    group('${entry.key} theme', () {
      final theme = entry.value;

      test('keeps filled buttons at least 48dp tall', () {
        final style = theme.filledButtonTheme.style!;
        final minimum = style.minimumSize?.resolve(const {});
        expect(minimum, isNotNull);
        expect(minimum!.height, greaterThanOrEqualTo(48));
      });

      test('keeps outlined buttons at least 48dp tall', () {
        final style = theme.outlinedButtonTheme.style!;
        final minimum = style.minimumSize?.resolve(const {});
        expect(minimum, isNotNull);
        expect(minimum!.height, greaterThanOrEqualTo(48));
      });

      test('keeps icon buttons at least 48dp wide and tall', () {
        final style = theme.iconButtonTheme.style!;
        final minimum = style.minimumSize?.resolve(const {});
        expect(minimum, isNotNull);
        expect(minimum!.width, greaterThanOrEqualTo(48));
        expect(minimum.height, greaterThanOrEqualTo(48));
      });

      test('expands small controls to padded tap targets', () {
        expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
      });

      test('enlarges body text for outdoor worker use', () {
        final bodyMedium = theme.textTheme.bodyMedium!;
        expect(bodyMedium.fontSize, greaterThanOrEqualTo(15));
      });
    });
  }

  test('light and dark themes use different scaffolds', () {
    expect(
      EarlyEchoTheme.lightTheme.scaffoldBackgroundColor,
      isNot(EarlyEchoTheme.darkTheme.scaffoldBackgroundColor),
    );
  });
}
