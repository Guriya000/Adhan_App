class SunTimings {
  final Results results;
  final String status;

  SunTimings({required this.results, required this.status});

  factory SunTimings.fromJson(Map<String, dynamic> json) {
    return SunTimings(
      results: Results.fromJson(json['results']),
      status: json['status'],
    );
  }
}

class Results {
  final String date;
  final String sunrise;
  final String sunset;
  final String firstLight;
  final String lastLight;
  final String dawn;
  final String dusk;
  final String solarNoon;
  final String goldenHour;
  final String dayLength;
  final String timezone;
  final int utcOffset;

  Results({
    required this.date,
    required this.sunrise,
    required this.sunset,
    required this.firstLight,
    required this.lastLight,
    required this.dawn,
    required this.dusk,
    required this.solarNoon,
    required this.goldenHour,
    required this.dayLength,
    required this.timezone,
    required this.utcOffset,
  });

  factory Results.fromJson(Map<String, dynamic> json) {
    return Results(
      date: json['date'],
      sunrise: json['sunrise'],
      sunset: json['sunset'],
      firstLight: json['first_light'],
      lastLight: json['last_light'],
      dawn: json['dawn'],
      dusk: json['dusk'],
      solarNoon: json['solar_noon'],
      goldenHour: json['golden_hour'],
      dayLength: json['day_length'],
      timezone: json['timezone'],
      utcOffset: json['utc_offset'],
    );
  }

  // Helper method to parse time strings like "6:28:06 AM"
  DateTime _parseTime(String time) {
    final parts = time.split(' ');
    final timeParts = parts[0].split(':');
    final hour = int.parse(timeParts[0]) +
        (parts[1] == 'PM' && timeParts[0] != '12' ? 12 : 0);
    final minute = int.parse(timeParts[1]);
    final second = int.parse(timeParts[2]);

    return DateTime.parse(
        "$date ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}");
  }

  Map<String, String> calculatePrayerTimes() {
    // Parse sunrise and sunset times
    DateTime sunriseTime = _parseTime(sunrise);
    DateTime sunsetTime = _parseTime(sunset);

    // Calculate Fajr (1.5 hours before sunrise)
    DateTime fajrTime = sunriseTime.subtract(Duration(hours: 1, minutes: 30));

    // Calculate Dhuhr (5 minutes after solar noon)
    DateTime dhuhrTime = _parseTime(solarNoon).add(Duration(minutes: 5));

    // Calculate Asr (midpoint between Dhuhr and Maghrib)
    DateTime asrTime = dhuhrTime.add(Duration(
        hours: (sunsetTime.difference(dhuhrTime).inHours / 2).round(),
        minutes: (sunsetTime.difference(dhuhrTime).inMinutes % 60) ~/ 2));

    // Calculate Maghrib (5 minutes after sunset)
    DateTime maghribTime = sunsetTime.add(Duration(minutes: 5));

    // Calculate Isha (1.5 hours after Maghrib)
    DateTime ishaTime = maghribTime.add(Duration(hours: 1, minutes: 30));

    // Format times to HH:MM AM/PM
    String formatTime(DateTime time) {
      return "${time.hour % 12}:${time.minute.toString().padLeft(2, '0')} ${time.hour < 12 ? 'AM' : 'PM'}";
    }

    return {
      'Fajr': formatTime(fajrTime),
      'Dhuhr': formatTime(dhuhrTime),
      'Asr': formatTime(asrTime),
      'Maghrib': formatTime(maghribTime),
      'Isha': formatTime(ishaTime),
    };
  }
}
