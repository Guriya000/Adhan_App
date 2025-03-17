import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

Animation<double>? animation;
AnimationController? animationController;
double begin = 0.0;

class _QiblaScreenState extends State<QiblaScreen>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    animation = Tween(begin: 0.0, end: 0.0).animate(animationController!);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        title: const Text(
          "Qibla Direction with respect to Your Location",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        children: [
          Align(
            alignment: const AlignmentDirectional(1.1, -1.7),
            child: Container(
              height: 200,
              width: 200,
              color: const Color.fromARGB(255, 80, 177, 194),
            ),
          ),
          Align(
            alignment: const AlignmentDirectional(-1.7, 1.2),
            child: Container(
              height: 200,
              width: 200,
              color: const Color.fromARGB(255, 161, 223, 233),
            ),
          ),
          Align(
            alignment: const AlignmentDirectional(0.5, -0.4),
            child: Container(
              height: 200,
              width: 200,
              color: Colors.pink.shade200,
            ),
          ),
          Align(
            alignment: const AlignmentDirectional(-0.9, -0.7),
            child: Container(
              height: 150,
              width: 200,
              color: Colors.amber.shade100,
            ),
          ),
          Align(
            alignment: const AlignmentDirectional(0.9, 0.6),
            child: Container(
              height: 200,
              width: 200,
              color: Colors.purple.shade200,
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
            child: Container(
              color: Colors.transparent,
            ),
          ),
          StreamBuilder(
              stream: FlutterQiblah.qiblahStream,
              builder: (context, snapshot) {
                if (snapshot == ConnectionState.waiting) {
                  return Container(
                    alignment: Alignment.center,
                    child: CircularProgressIndicator(
                      color: Colors.teal.shade400,
                    ),
                  );
                }
                final qiblahDirection = snapshot.data;
                animation = Tween(
                        begin: begin,
                        end: (qiblahDirection!.qiblah * (pi / 180) * -1))
                    .animate(animationController!);
                begin = (qiblahDirection.qiblah * (pi / 180) * -1);
                animationController!.forward(from: 0);
                return Center(
                  child: SizedBox(
                    child: AnimatedBuilder(
                        animation: animation!,
                        builder: (context, child) => Transform.rotate(
                              angle: animation!.value,
                              child: Image.asset("assets/hh.png"),
                            )),
                  ),
                );
              })
        ],
      ),
    );
  }
}
