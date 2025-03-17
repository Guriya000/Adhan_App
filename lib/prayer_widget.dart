import 'package:flutter/material.dart';

class PrayerWidget extends StatefulWidget {
  final String prayerName;
  final String prayerTime;
  final Image prayerImage;
  final Color tilecolor;

  const PrayerWidget(
      {super.key,
      required this.prayerName,
      required this.tilecolor,
      required this.prayerTime,
      required this.prayerImage});

  @override
  State<PrayerWidget> createState() => _PrayerWidgetState();
}

class _PrayerWidgetState extends State<PrayerWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      width: 140,
      decoration: BoxDecoration(
          color: widget.tilecolor,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 5,
            ),
          ]),
      child: Padding(
        padding: const EdgeInsets.only(top: 12, left: 12, right: 4),
        child: Row(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  widget.prayerName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.prayerTime,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(
              width: 7,
            ),
            Container(
              height: 50,
              width: 50,
              child: widget.prayerImage,
            ),
          ],
        ),
      ),
    );
  }
}
