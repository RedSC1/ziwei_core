import 'package:ziwei_core/src/data/palace.dart';
import 'package:ziwei_core/src/enums/gan_zhi.dart';

class ZiWeiPlate {
  final List<Palace> palaces;
  final int originMingIndex;
  final int bodyPalaceIndex;
  final FiveElementBureau elementBureau;

  int? decadeMingIndex;
  int? yearMingIndex;
  int? monthMingIndex;
  int? dayMingIndex;
  int? hourMingIndex;
  ZiWeiPlate({
    required this.palaces,
    required this.originMingIndex,
    required this.bodyPalaceIndex,
    required this.elementBureau,
    this.decadeMingIndex,
    this.yearMingIndex,
    this.monthMingIndex,
    this.dayMingIndex,
    this.hourMingIndex,
  });
}
