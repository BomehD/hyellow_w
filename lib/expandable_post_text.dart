import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ExpandablePostText extends StatefulWidget {
  final String text;

  const ExpandablePostText({Key? key, required this.text}) : super(key: key);

  @override
  _ExpandablePostTextState createState() => _ExpandablePostTextState();
}

class _ExpandablePostTextState extends State<ExpandablePostText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(fontSize: 12);

    return LayoutBuilder(
      builder: (context, constraints) {
        final span = TextSpan(text: widget.text, style: textStyle);
        final tp = TextPainter(
          text: span,
          maxLines: 3,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        final textExceedsLimit = tp.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: textStyle,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              maxLines: _expanded ? null : 3,
            ),
            if (textExceedsLimit)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _expanded ? "Show less" : "Read more",
                    style: TextStyle(fontSize: 10, color: Colors.black,
                      fontWeight: FontWeight.bold,),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
