/// 地理位置（经纬度）
class Location {
  /// 经度（度），东正西负
  final double longitude;

  /// 纬度（度），北正南负
  final double latitude;

  const Location(this.longitude, this.latitude);

  /// 北京
  static const beijing = Location(116.4074, 39.9042);

  @override
  String toString() => 'Location($longitude, $latitude)';
}
