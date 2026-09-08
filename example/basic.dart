import 'package:ziwei_core/ziwei_core.dart';

void main() {
  final birth = resolveZiweiBirth(
    ZonedTime(year: 2000, month: 1, day: 1, hour: 12, offsetMinutes: 480),
    ZiweiOptions(
      gender: ZiweiGender.male,
      calendarOptions: CalendarOptions(eventAccuracy: Accuracy.mid),
    ),
  );
  print('五行局：${birth.anchors.bureau.number}；紫微：${birth.anchors.ziwei}');
  final manual = arrangeZiweiStars(
    ZiweiPlacementInput(
      yearGanIndex: 9,
      yearZhiIndex: 7,
      month: 3,
      day: 14,
      hourZhiIndex: 4,
    ),
    gender: ZiweiGender.male,
  );
  print(manual.starPositions);
  print('无法计算的规则：${manual.omittedPlacements.length}');
}
