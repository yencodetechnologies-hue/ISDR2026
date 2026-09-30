import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:isdr/features/auth/data/repositories/auth_repository.dart';
import 'package:isdr/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:isdr/features/auth/presentation/pages/login_page.dart';

/// iPad Air 11-inch (M3) logical points: 820 × 1180.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpLogin(
    WidgetTester tester, {
    required Size size,
    double keyboardInset = 0,
    double topPadding = 24,
    double bottomPadding = 20,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = FakeViewPadding(top: topPadding, bottom: bottomPadding);
    tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => AuthBloc(authRepository: AuthRepository()),
          child: const LoginPage(),
        ),
      ),
    );
    await tester.pump();
  }

  void expectVisibleOnScreen(WidgetTester tester, Finder finder, Size size) {
    expect(finder, findsOneWidget);
    final rect = tester.getRect(finder);
    final bottomLimit = size.height - tester.view.viewInsets.bottom + 1;
    expect(rect.top, greaterThanOrEqualTo(-1), reason: '$finder top off-screen: $rect');
    expect(
      rect.bottom,
      lessThanOrEqualTo(bottomLimit),
      reason: '$finder bottom off-screen: $rect (limit $bottomLimit)',
    );
    expect(rect.left, greaterThanOrEqualTo(-1));
    expect(rect.right, lessThanOrEqualTo(size.width + 1));
  }

  testWidgets('iPad Air 11 portrait shows Login without scrolling', (tester) async {
    const size = Size(820, 1180);
    await pumpLogin(tester, size: size);

    // Apple reviewers must see Login on first paint — no scroll required.
    expectVisibleOnScreen(tester, find.text('Login'), size);
    expectVisibleOnScreen(tester, find.text('Welcome Back'), size);
    expectVisibleOnScreen(tester, find.text('Forgot Password?'), size);
    expectHeroBelowStatusBar(tester, 24);
  });

  testWidgets('iPad Air 11 landscape shows Login without scrolling', (tester) async {
    const size = Size(1180, 820);
    await pumpLogin(tester, size: size);

    expectVisibleOnScreen(tester, find.text('Login'), size);
    expectVisibleOnScreen(tester, find.text('Welcome Back'), size);
  });

  testWidgets('iPad Air 11 portrait keeps Login above the keyboard', (tester) async {
    const size = Size(820, 1180);
    await pumpLogin(tester, size: size, keyboardInset: 420);

    final login = find.text('Login');
    await tester.ensureVisible(login);
    await tester.pumpAndSettle();
    expectVisibleOnScreen(tester, login, size);
  });

  testWidgets('phone portrait keeps the poster below the status bar',
      (tester) async {
    const size = Size(390, 844);
    const topPadding = 47.0;
    await pumpLogin(
      tester,
      size: size,
      topPadding: topPadding,
      bottomPadding: 34,
    );

    expectVisibleOnScreen(tester, find.text('Login'), size);
    expectVisibleOnScreen(tester, find.text('Welcome Back'), size);
    expectHeroBelowStatusBar(tester, topPadding);
  });

  testWidgets('dynamic island phone keeps Login and the poster top on screen',
      (tester) async {
    // iPhone 17-class: tall phone, Dynamic Island inset.
    const size = Size(402, 874);
    const topPadding = 59.0;
    await pumpLogin(
      tester,
      size: size,
      topPadding: topPadding,
      bottomPadding: 34,
    );

    expectVisibleOnScreen(tester, find.text('Login'), size);
    expectVisibleOnScreen(tester, find.text('Welcome Back'), size);
    expectHeroBelowStatusBar(tester, topPadding);
    // The button sits fully above the footer wave, not just its label.
    final login = tester.getRect(find.text('Login'));
    expect(login.bottom, lessThan(size.height - 100));
  });
}

void expectHeroBelowStatusBar(WidgetTester tester, double topPadding) {
  final hero = tester.getRect(find.byType(Image));
  expect(
    hero.top,
    greaterThanOrEqualTo(topPadding - 1),
    reason:
        'poster top is under the status bar ($hero, inset $topPadding), so the top logo row is hidden',
  );
}
