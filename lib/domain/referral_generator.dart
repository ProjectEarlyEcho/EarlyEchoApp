import 'package:intl/intl.dart';

import '../data/models/deic_center.dart';
import '../data/models/session_model.dart';

/// Builds the plain-language Hindi referral letter shown on the referral
/// screen and attached when sharing via WhatsApp.
///
/// The letter never includes the child name unless explicitly enabled.
class ReferralGenerator {
  static String buildLetterText(
    SessionModel session, {
    DeicCenter? nearestDeic,
  }) {
    final date = DateFormat('d MMMM y').format(session.sessionDate);
    final buffer = StringBuffer()
      ..writeln('EarlyEcho — विकासात्मक स्क्रीनिंग रेफरल')
      ..writeln()
      ..writeln('तारीख: $date')
      ..writeln('बच्चे की उम्र: ${session.childAgeMonths} महीने')
      ..writeln('Anganwadi ID: ${session.anganwadiId}')
      ..writeln('राज्य: ${session.stateCode}')
      ..writeln('जिला: ${session.districtCode}')
      ..writeln()
      ..writeln('विश्लेषण का परिणाम:')
      ..writeln(
        _biomarkerLine(
          'VTTL',
          '${session.vttlMs.toStringAsFixed(0)} ms',
          session.vttlFlagged,
          'सामान्य सीमा (>1000 ms) से अधिक',
        ),
      )
      ..writeln(
        _biomarkerLine(
          'CVR',
          session.cvrRatio.toStringAsFixed(3),
          session.cvrFlagged,
          'कम वोकलाइज़ेशन अनुपात',
        ),
      )
      ..writeln(
        _biomarkerLine(
          'PFV',
          '${session.pfvStd.toStringAsFixed(1)} ST',
          session.pfvFlagged,
          'सपाट प्रोसोडी',
        ),
      )
      ..writeln()
      ..writeln('सिफारिश:')
      ..writeln('इस बच्चे के लिए आगे की व्यापक विकासात्मक जाँच आवश्यक है।')
      ..writeln('कृपया नीचे दिए गए DEIC से संपर्क करें।')
      ..writeln()
      ..writeln('निकटतम DEIC:')
      ..writeln(nearestDeic?.name ?? 'स्थानीय DEIC निर्देशिका देखें');

    if (nearestDeic != null) {
      buffer
        ..writeln('राज्य: ${nearestDeic.state}')
        ..writeln('जिला: ${nearestDeic.district}');
      if (nearestDeic.contact != null) {
        buffer.writeln('संपर्क विवरण: ${nearestDeic.contact}');
      }
    }

    buffer
      ..writeln()
      ..writeln('उत्पादित: EarlyEcho Acoustic Screening System');

    return buffer.toString();
  }

  static String _biomarkerLine(
    String label,
    String value,
    bool flagged,
    String flaggedNote,
  ) {
    return flagged
        ? '$label: $value ⚠ $flaggedNote'
        : '$label: $value ✓ सामान्य';
  }
}
