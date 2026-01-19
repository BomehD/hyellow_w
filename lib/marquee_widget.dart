import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

class MarqueeWidget extends StatelessWidget {
  final String interest;
  final double maxWidth;
  final double height;
  final TextStyle style;

  const MarqueeWidget({
    Key? key,
    required this.interest,
    this.maxWidth = 100, // Adjust width as needed
    this.height = 20,
    this.style = const TextStyle(fontSize: 10, color: Colors.grey),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: interest, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    final bool isOverflowing = textPainter.width > maxWidth;

    return SizedBox(
      height: height,
      width: maxWidth,
      child: Marquee(
        text: interest,
        style: style,
        scrollAxis: Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.start,
        blankSpace: 20.0,
        velocity: 40.0,
        pauseAfterRound: Duration(seconds: 5),
        startPadding: 10.0,
        accelerationDuration: Duration(milliseconds: 300),
        accelerationCurve: Curves.linear,
        decelerationDuration: Duration(milliseconds: 300),
        decelerationCurve: Curves.easeOut,
      ),
    );

  }
}
