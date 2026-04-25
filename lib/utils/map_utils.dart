import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class MapUtils {
  MapUtils._();

  static Future<void> openMap(String address) async {
    String googleUrl = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}';
    String appleUrl = 'https://maps.apple.com/?q=${Uri.encodeComponent(address)}';

    if (Platform.isIOS) {
      if (await canLaunchUrl(Uri.parse(googleUrl))) {
        await launchUrl(Uri.parse(googleUrl), mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(Uri.parse(appleUrl))) {
        await launchUrl(Uri.parse(appleUrl), mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch maps';
      }
    } else {
      if (await canLaunchUrl(Uri.parse(googleUrl))) {
        await launchUrl(Uri.parse(googleUrl), mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $googleUrl';
      }
    }
  }

  static Future<void> openMapWithCoords(double lat, double lng) async {
    String googleUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    String appleUrl = 'https://maps.apple.com/?ll=$lat,$lng';

    if (Platform.isIOS) {
       if (await canLaunchUrl(Uri.parse(googleUrl))) {
        await launchUrl(Uri.parse(googleUrl), mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(Uri.parse(appleUrl))) {
        await launchUrl(Uri.parse(appleUrl), mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch maps';
      }
    } else {
      if (await canLaunchUrl(Uri.parse(googleUrl))) {
        await launchUrl(Uri.parse(googleUrl), mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $googleUrl';
      }
    }
  }

  static Future<void> openFullRoute({
    required List<Map<String, double>> waypoints,
    required Map<String, double> destination,
  }) async {
    // Construct Google Maps Directions URL
    // Format: https://www.google.com/maps/dir/?api=1&destination=LAT,LNG&waypoints=LAT1,LNG1|LAT2,LNG2
    
    final String destStr = "${destination['lat']},${destination['lng']}";
    final String waypointsStr = waypoints.map((w) => "${w['lat']},${w['lng']}").join('|');
    
    String googleUrl = 'https://www.google.com/maps/dir/?api=1&destination=$destStr';
    if (waypointsStr.isNotEmpty) {
      googleUrl += '&waypoints=$waypointsStr';
    }

    // fallback for iOS if google maps not installed
    String appleUrl = 'https://maps.apple.com/?daddr=$destStr';

    if (Platform.isIOS) {
      if (await canLaunchUrl(Uri.parse(googleUrl))) {
        await launchUrl(Uri.parse(googleUrl), mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(Uri.parse(appleUrl))) {
        await launchUrl(Uri.parse(appleUrl), mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch maps';
      }
    } else {
      if (await canLaunchUrl(Uri.parse(googleUrl))) {
        await launchUrl(Uri.parse(googleUrl), mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $googleUrl';
      }
    }
  }
}
