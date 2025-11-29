import 'package:flutter/material.dart';

/// Empty cell that only shows plus icon on hover
class EmptyCellHoverIndicator extends StatefulWidget {
  final VoidCallback onTap;

  const EmptyCellHoverIndicator({
    super.key,
    required this.onTap,
  });

  @override
  State<EmptyCellHoverIndicator> createState() => _EmptyCellHoverIndicatorState();
}

class _EmptyCellHoverIndicatorState extends State<EmptyCellHoverIndicator> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque, // Make entire area tappable
        child: Container(
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isHovered ? const Color(0xff0386FF).withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: _isHovered 
                  ? Border.all(color: const Color(0xff0386FF).withOpacity(0.3), width: 1)
                  : null,
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _isHovered ? 1.0 : 0.0,
              child: SizedBox(
                width: 20,
                height: 20,
                child: Icon(
                  Icons.add,
                  size: _isHovered ? 20 : 0,
                  color: const Color(0xff0386FF),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

