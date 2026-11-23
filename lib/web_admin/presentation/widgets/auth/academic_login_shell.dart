import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import 'login_design.dart';

/// A school folio and a single, quiet sign-in surface.
class AcademicLoginShell extends StatelessWidget {
  final Widget form;
  const AcademicLoginShell({super.key, required this.form});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 1000;
          final phone = constraints.maxWidth < 600;
          final padding = phone ? 24.0 : 40.0;
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: padding,
                  vertical: phone ? 28 : 36,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _BrandHeader(compact: phone),
                        SizedBox(
                          height: desktop
                              ? 40
                              : phone
                              ? 44
                              : 56,
                        ),
                        if (desktop)
                          // 6 columns + gutter + 6 columns = 542 + 16 + 542 = 1100px.
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Expanded(child: _AcademicFolio()),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 48,
                                  ),
                                  child: form,
                                ),
                              ),
                            ],
                          )
                        else
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: form,
                          ),
                        SizedBox(height: desktop ? 32 : 40),
                        _PageFooter(compact: phone),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _BrandHeader extends StatelessWidget {
  final bool compact;
  const _BrandHeader({required this.compact});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Image.asset(
        'assets/Logo MTS.png',
        width: compact ? 44 : 50,
        height: compact ? 48 : 54,
        semanticLabel: 'Lambang ${AppConstants.schoolName}',
        filterQuality: FilterQuality.high,
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppConstants.schoolName,
              style: TextStyle(
                fontFamily: LoginDesign.sans,
                fontSize: compact ? 15 : 17,
                fontWeight: FontWeight.w600,
                height: 1.3,
                color: LoginDesign.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Sistem Informasi Madrasah',
              style: TextStyle(
                fontFamily: LoginDesign.sans,
                fontSize: 12,
                color: LoginDesign.muted,
              ),
            ),
          ],
        ),
      ),
      if (!compact) ...[
        const SizedBox(width: 20),
        const Icon(Icons.school_outlined, size: 18, color: LoginDesign.muted),
        const SizedBox(width: 8),
        const Text(
          'Portal administrasi',
          style: TextStyle(
            fontFamily: LoginDesign.sans,
            fontSize: 13,
            color: LoginDesign.muted,
          ),
        ),
      ],
    ],
  );
}

class _AcademicFolio extends StatelessWidget {
  const _AcademicFolio();
  @override
  Widget build(BuildContext context) => Container(
    height:
        574 + math.max(0, MediaQuery.textScalerOf(context).scale(1) - 1) * 260,
    padding: const EdgeInsets.fromLTRB(40, 40, 40, 30),
    decoration: BoxDecoration(
      color: LoginDesign.paper,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: const Text(
            'Setiap kehadiran,\nawal pembelajaran.',
            style: TextStyle(
              fontFamily: LoginDesign.serif,
              fontSize: 48,
              fontWeight: FontWeight.w400,
              height: 1.06,
              letterSpacing: -0.8,
              color: LoginDesign.ink,
            ),
          ),
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 355),
          child: const Text(
            'Kelola presensi, data siswa, dan surat keterangan dalam satu ruang administrasi madrasah.',
            style: TextStyle(
              fontFamily: LoginDesign.sans,
              fontSize: 14,
              height: 1.65,
              color: LoginDesign.muted,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Expanded(
          child: ExcludeSemantics(
            child: SizedBox(
              width: double.infinity,
              child: CustomPaint(painter: _SchoolFolioPainter()),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Row(
          children: [
            Icon(Icons.menu_book_outlined, color: LoginDesign.forest, size: 17),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Hadir. Tercatat. Terhubung.',
                style: TextStyle(
                  fontFamily: LoginDesign.sans,
                  color: LoginDesign.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _PageFooter extends StatelessWidget {
  final bool compact;
  const _PageFooter({required this.compact});
  @override
  Widget build(BuildContext context) {
    const descriptor = Text(
      'Presensi dan administrasi madrasah',
      style: TextStyle(
        fontFamily: LoginDesign.sans,
        fontSize: 12,
        color: LoginDesign.muted,
      ),
    );
    final copyright = Text(
      '© ${DateTime.now().year} ${AppConstants.schoolName}',
      style: const TextStyle(
        fontFamily: LoginDesign.sans,
        fontSize: 12,
        color: LoginDesign.muted,
      ),
    );
    if (compact) {
      return Column(
        children: [descriptor, const SizedBox(height: 8), copyright],
      );
    }
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 20,
        runSpacing: 8,
        children: [copyright, descriptor],
      ),
    );
  }
}

/// The book and pen refer to the school crest, not a fictional campus.
class _SchoolFolioPainter extends CustomPainter {
  const _SchoolFolioPainter();
  @override
  void paint(Canvas canvas, Size size) {
    const design = Size(440, 238);
    final scale = math.min(
      size.width / design.width,
      size.height / design.height,
    );
    canvas.save();
    canvas.translate(
      (size.width - design.width * scale) / 2,
      (size.height - design.height * scale) / 2,
    );
    canvas.scale(scale);
    final ink = Paint()
      ..color = LoginDesign.forest
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final page = Paint()..color = const Color(0xFFFCFDF9);
    final cover = Paint()..color = const Color(0xFFD9E4D7);
    final left = Path()
      ..moveTo(47, 52)
      ..quadraticBezierTo(126, 30, 221, 70)
      ..lineTo(221, 212)
      ..quadraticBezierTo(135, 180, 47, 196)
      ..close();
    final right = Path()
      ..moveTo(221, 70)
      ..quadraticBezierTo(310, 30, 393, 52)
      ..lineTo(393, 196)
      ..quadraticBezierTo(311, 181, 221, 212)
      ..close();
    canvas.drawPath(
      Path()
        ..moveTo(39, 58)
        ..lineTo(39, 204)
        ..quadraticBezierTo(131, 189, 221, 221)
        ..quadraticBezierTo(312, 190, 401, 204)
        ..lineTo(401, 58)
        ..lineTo(393, 52)
        ..lineTo(221, 70)
        ..lineTo(47, 52)
        ..close(),
      cover,
    );
    canvas.drawPath(left, page);
    canvas.drawPath(right, page);
    canvas.drawPath(left, ink);
    canvas.drawPath(right, ink);
    canvas.drawLine(const Offset(221, 77), const Offset(221, 207), ink);
    final print = Paint()
      ..color = const Color(0xFFB3C5B4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    for (var row = 0; row < 5; row++) {
      final y = 83.0 + row * 20;
      canvas.drawPath(
        Path()
          ..moveTo(74, y)
          ..quadraticBezierTo(135, y - 7, 194, y + 13),
        print,
      );
      canvas.drawPath(
        Path()
          ..moveTo(246, y + 13)
          ..quadraticBezierTo(307, y - 7, 367, y),
        print,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(312, 49)
        ..lineTo(324, 46)
        ..lineTo(324, 121)
        ..lineTo(318, 116)
        ..lineTo(312, 124)
        ..close(),
      Paint()..color = const Color(0xFF8C9974),
    );
    canvas.save();
    canvas.translate(338, 20);
    canvas.rotate(0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-5, 0, 10, 136),
        const Radius.circular(3),
      ),
      Paint()..color = LoginDesign.forest,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-5, 136)
        ..lineTo(0, 154)
        ..lineTo(5, 136)
        ..close(),
      Paint()..color = const Color(0xFFA6AE99),
    );
    canvas.drawLine(const Offset(0, 154), const Offset(0, 159), ink);
    canvas.drawLine(
      const Offset(-1, 8),
      const Offset(-1, 44),
      Paint()
        ..color = const Color(0xFFC8D5C5)
        ..strokeWidth = 1.4,
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SchoolFolioPainter oldDelegate) => false;
}
