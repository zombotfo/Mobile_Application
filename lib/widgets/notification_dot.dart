import 'package:flutter/material.dart';

class NotificationDot extends StatelessWidget {
  const NotificationDot({
    super.key,
    required this.show,
    required this.child,
    this.size = 9,
  });

  final bool show;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (show)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
