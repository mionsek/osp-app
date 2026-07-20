import 'package:flutter_test/flutter_test.dart';
import 'package:osp_app/core/constants/handover_recipient_types.dart';
import 'package:osp_app/models/models.dart';

void main() {
  group('PropertyHandover', () {
    PropertyHandover build({
      String recipientType = HandoverRecipientTypes.owner,
      String? recipientTypeOther,
    }) {
      final now = DateTime(2026, 7, 20, 12, 0);
      return PropertyHandover(
        id: '1',
        eventDate: now,
        eventTime: now,
        recipientType: recipientType,
        recipientTypeOther: recipientTypeOther,
        signDate: now,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('recipientTypeLabel returns the closed-list value by default', () {
      final h = build(recipientType: HandoverRecipientTypes.police);
      expect(h.recipientTypeLabel, HandoverRecipientTypes.police);
    });

    test(
        'recipientTypeLabel falls back to recipientTypeOther when set '
        'and non-empty', () {
      final h = build(
        recipientType: HandoverRecipientTypes.other,
        recipientTypeOther: 'Straż leśna',
      );
      expect(h.recipientTypeLabel, 'Straż leśna');
    });

    test('recipientTypeLabel ignores a blank recipientTypeOther', () {
      final h = build(
        recipientType: HandoverRecipientTypes.owner,
        recipientTypeOther: '   ',
      );
      expect(h.recipientTypeLabel, HandoverRecipientTypes.owner);
    });
  });

  group('HandoverRecipientTypes', () {
    test('closed list matches the paper form, "Inne" listed last', () {
      expect(HandoverRecipientTypes.all.last, HandoverRecipientTypes.other);
      expect(HandoverRecipientTypes.all.length, 8);
      expect(HandoverRecipientTypes.all.toSet().length, 8,
          reason: 'no duplicate entries');
    });
  });
}
