import 'package:url_launcher/url_launcher.dart';

Uri dateMapUri({required String place, double? latitude, double? longitude}) =>
    Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': latitude != null && longitude != null
          ? '$latitude,$longitude'
          : place,
    });
Future<bool> openDateMap({
  required String place,
  double? latitude,
  double? longitude,
}) => launchUrl(
  dateMapUri(place: place, latitude: latitude, longitude: longitude),
  mode: LaunchMode.externalApplication,
);
