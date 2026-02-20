enum FiveElementBureau {
  water2, // index 0
  wood3, // index 1
  metal4, // index 2
  earth5, // index 3
  fire6; // index 4

  int get number => const [2, 3, 4, 5, 6][index];
  String get label => const ['水二局', '木三局', '金四局', '土五局', '火六局'][index];
}
