import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:adhaan_app/SunriseSunsetData.dart';
import 'package:adhaan_app/main.dart';
import 'package:adhaan_app/prayer_widget.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;
import 'package:hijri/hijri_calendar.dart';

class MyScreen extends StatefulWidget {
  const MyScreen({super.key});

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  late Future<Map<String, dynamic>> sunriseSunsetData;
// Logic for displaying current data and time.
  String _currentDate = "";
  String _currentTime = "";

  String _hijriDate = "";

  void _updateHijriDate() {
    final hijriCalendar = HijriCalendar.now();

    setState(() {
      _hijriDate =
          "${hijriCalendar.hDay} ${hijriCalendar.longMonthName} ${hijriCalendar.hYear}";
    });
  }

  void _updateDateTime() {
    // Get the current date and time
    DateTime now = DateTime.now();

    // Format the date and time
    String formattedDate =
        "${now.day}-${_twoDigits(now.month)}-${_twoDigits(now.year)}";
    String formattedTime =
        "${_twoDigits(now.hour)}:${_twoDigits(now.minute)}:${_twoDigits(now.second)}";

    // Update the state
    setState(() {
      _currentDate = "${formattedDate}";
      _currentTime = "${formattedTime}";
    });
  }

// Helper function to ensure two digits (e.g., 01 instead of 1)
  String _twoDigits(int n) {
    return n.toString().padLeft(2, '0');
  }

  //logic for time setting.
  String _currentDay = "";

  void _updateCurrentDay() {
    // Get the current date
    DateTime now = DateTime.now();

    // Get the current day as a string (e.g., Monday, Tuesday, etc.)
    String day = _getDayName(now.weekday);

    // Update the state
    setState(() {
      _currentDay = day;
    });
  }

  // Helper function to convert weekday number to day name
  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return "Monday";
      case 2:
        return "Tuesday";
      case 3:
        return "Wednesday";
      case 4:
        return "Thursday";
      case 5:
        return "Friday";
      case 6:
        return "Saturday";
      case 7:
        return "Sunday";
      default:
        return "Unknown";
    }
  }

  //updating the day every midnight
  Timer? _timer;
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

// setting for displaying the area name.

  String _areaName = "Loading.";

  @override
  void initState() {
    super.initState();
    _getLocation();
    _updateDateTime();
    fetchSunTimings();
    _updateCurrentDay();
    getNextPrayerTime();
    _updateHijriDate();

    _timer = Timer.periodic(const Duration(minutes: 1), (Timer t) {
      _updateCurrentDay();
      _updateHijriDate();
    });
  }

  Future<void> _getLocation() async {
    // Check location permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _areaName = "Location services are disabled.";
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _areaName = "Permissions denied";
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _areaName = "Location permissions are permanently denied.";
      });
      return;
    }

    // Get the current position
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // Reverse geocoding to get the area name
    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (placemarks.isNotEmpty) {
      Placemark placemark = placemarks[0];
      setState(() {
        _areaName = placemark.locality ?? "Unknown area";
      });
    } else {
      setState(() {
        _areaName = "Unable to fetch area name.";
      });
    }
  }

  Future<SunTimings> fetchSunTimings() async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    var latitude = position.latitude;
    var longitude = position.longitude;
    final response = await http.get(Uri.parse(
        'https://api.sunrisesunset.io/json?lat=$latitude&lng=$longitude'));

    if (response.statusCode == 200) {
      return SunTimings.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load sun timings');
    }
  }

  Future<String> getNextPrayerTime() async {
    final timings = await fetchSunTimings();
    final prayerTimes = timings.results.calculatePrayerTimes();
    final now = DateTime.now();

    for (var prayer in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      final prayerTime = prayerTimes[prayer]!;
      final prayerTimeParts = prayerTime.split(' ');
      final timeParts = prayerTimeParts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      if (prayerTimeParts[1] == 'PM' && hour != 12) {
        hour += 12;
      } else if (prayerTimeParts[1] == 'AM' && hour == 12) {
        hour = 0;
      }

      final prayerDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (prayerDateTime.isAfter(now)) {
        return "$prayer at ${prayerTime}";
      }
    }

    // If no upcoming prayer time is found for today, return the first prayer time of the next day
    final firstPrayerTime = prayerTimes['Fajr']!;
    return "Fajr at $firstPrayerTime";
  }

  final AudioPlayer _audioPlayer = AudioPlayer();

  void _scheduleAdhaan() async {
    final timings = await fetchSunTimings();
    final prayerTimes = timings.results.calculatePrayerTimes();
    final now = DateTime.now();

    for (var prayer in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      final prayerTime = prayerTimes[prayer]!;
      final prayerTimeParts = prayerTime.split(' ');
      final timeParts = prayerTimeParts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      if (prayerTimeParts[1] == 'PM' && hour != 12) {
        hour += 12;
      } else if (prayerTimeParts[1] == 'AM' && hour == 12) {
        hour = 0;
      }

      final prayerDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (prayerDateTime.isAfter(now)) {
        final duration = prayerDateTime.difference(now);
        Timer(duration, () {
          _showNotification(prayer);
          _playAdhaan();
        });
      }
    }
  }

  void _showNotification(String prayer) async {
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('app_icon');

    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'adhan_channel',
      'Adhan Notifications',
      channelDescription: 'Channel for Adhan notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      'Prayer Time',
      'It\'s time for $prayer prayer',
      platformChannelSpecifics,
      payload: 'item x',
    );
  }

  // void _scheduleAdhaan() async {
  //   final timings = await fetchSunTimings();
  //   final prayerTimes = timings.results.calculatePrayerTimes();

  //   final now = DateTime.now();

  //   for (var prayer in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
  //     final prayerTime = prayerTimes[prayer]!;
  //     final prayerTimeParts = prayerTime.split(' ');
  //     final timeParts = prayerTimeParts[0].split(':');
  //     int hour = int.parse(timeParts[0]);
  //     final minute = int.parse(timeParts[1]);

  //     if (prayerTimeParts[1] == 'PM' && hour != 12) {
  //       hour += 12;
  //     } else if (prayerTimeParts[1] == 'AM' && hour == 12) {
  //       hour = 0;
  //     }

  //     final prayerDateTime = DateTime(
  //       now.year,
  //       now.month,
  //       now.day,
  //       hour,
  //       minute,
  //     );

  //     if (prayerDateTime.isAfter(now)) {
  //       final duration = prayerDateTime.difference(now);
  //       Timer(duration, () {
  //         _playAdhaan();
  //       });
  //     }
  //   }
  // }

  void _playAdhaan() async {
    final player = AudioCache(prefix: 'assets/');
    final url = await player.load('azan.mp3');
    await _audioPlayer.play(DeviceFileSource(url.path));
  }

  bool isPlaying = true;
  void _stopAdhaan() {
    _audioPlayer.stop();
    isPlaying = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Stack(
            children: [
              Container(
                height: 280,
                width: double.infinity,
                decoration: const BoxDecoration(
                    image: DecorationImage(
                        image: AssetImage("assets/mosque.jpg"),
                        fit: BoxFit.cover)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 60, left: 18),
                      child: Container(
                        width: 100,
                        decoration: BoxDecoration(
                            backgroundBlendMode: BlendMode.overlay,
                            color: Colors.blue.shade100.withOpacity(0.5),
                            border: Border.all(color: Colors.black, width: 1),
                            borderRadius: BorderRadius.circular(8)),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 18,
                                color: Colors.red,
                              ),
                              const SizedBox(
                                width: 3,
                              ),
                              Text(
                                _areaName,
                                style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 160, left: 15, right: 15),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.6),
                        blurRadius: 10,
                        spreadRadius: 5,
                      ),
                    ],
                    backgroundBlendMode: BlendMode.overlay,
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 15, right: 15, top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _hijriDate,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black),
                        ),
                        Text(
                          _currentDate,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black),
                        ),
                        Text(
                          _currentDay,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black),
                        ),
                        const SizedBox(
                          height: 27.5,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Row(
                              children: [
                                Container(
                                  height: 40,
                                  width: 40,
                                  child: Image.asset("assets/sun-shine.png"),
                                ),
                                FutureBuilder<SunTimings>(
                                    future: fetchSunTimings(),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData) {
                                        final data = snapshot.data;
                                        return Column(
                                          children: [
                                            const Text("Sunrise",
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w800)),
                                            Text(data!.results.sunrise,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w500)),
                                          ],
                                        );
                                      } else {
                                        return const Text("null");
                                      }
                                    })
                              ],
                            ),
                            Row(
                              children: [
                                Container(
                                  height: 40,
                                  width: 40,
                                  child: Image.asset("assets/sunset.png"),
                                ),
                                FutureBuilder<SunTimings>(
                                    future: fetchSunTimings(),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData) {
                                        final data = snapshot.data;
                                        return Column(
                                          children: [
                                            const Text("Sunset",
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w800)),
                                            Text(data!.results.sunset,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w500)),
                                          ],
                                        );
                                      } else {
                                        return const Text("null");
                                      }
                                    }),
                              ],
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 10,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 17, left: 17),
            child: Container(
              height: 40,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.blue.shade100,
                  Colors.teal.shade100,
                  Colors.deepOrange.shade100
                ], transform: GradientRotation(pi / 20)),
                // color: Colors.lightGreen.shade100,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 5,
                  ),
                ],

                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const Text(
                      "Next Prayer Time: ",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(
                      width: 15,
                    ),
                    FutureBuilder(
                        future: getNextPrayerTime(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            // ignore: prefer_const_constructors
                            return Text("Loading...",
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w200));
                          } else if (snapshot.hasData) {
                            final data = snapshot.data;
                            return Text(data.toString(),
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w800));
                          } else {
                            return const Text("null");
                          }
                        })
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(
            height: 15,
          ),
          FutureBuilder(
              future: fetchSunTimings(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Text(
                      "Loading...",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  );
                } else {
                  final timings = snapshot.data!.results;
                  final prayerTimes = timings.calculatePrayerTimes();
                  _scheduleAdhaan();
                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          PrayerWidget(
                              prayerName: "Fajr",
                              tilecolor: Colors.brown.shade100,
                              prayerTime: prayerTimes['Fajr']!,
                              prayerImage: Image.asset("assets/fajr.png")),
                          PrayerWidget(
                              prayerName: "Dhuhar",
                              tilecolor: Colors.pink.shade100,
                              prayerTime: prayerTimes['Dhuhr']!,
                              prayerImage: Image.asset("assets/zohar.png")),
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          PrayerWidget(
                              prayerName: "Asr",
                              tilecolor: Colors.amber.shade100,
                              prayerTime: prayerTimes['Asr']!,
                              prayerImage: Image.asset("assets/asr.png")),
                          PrayerWidget(
                              prayerName: "Maghrib",
                              tilecolor: Colors.green.shade100,
                              prayerTime: prayerTimes['Maghrib']!,
                              prayerImage: Image.asset("assets/maghrib.png")),
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          const SizedBox(
                            width: 27,
                          ),
                          PrayerWidget(
                              prayerName: "Esha",
                              tilecolor: Colors.purple.shade100,
                              prayerTime: prayerTimes['Isha']!,
                              prayerImage: Image.asset("assets/esha.png")),
                        ],
                      )
                    ],
                  );
                }
              }),
        ],
      ),
      floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.lightGreen.shade100,
          hoverColor: Colors.pink.shade100,
          child: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
          onPressed: () {
            if (isPlaying) {
              _stopAdhaan();
            } else {
              _playAdhaan();
            }
            isPlaying = !isPlaying;
          }),
    );
  }
}
