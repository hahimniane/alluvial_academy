import 'package:flutter/material.dart';

class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext, BoxConstraints, DeviceType) builder;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return builder(context, constraints, getDeviceType(constraints));
      },
    );
  }

  static DeviceType getDeviceType(BoxConstraints constraints) {
    if (constraints.maxWidth >= 1024) {
      return DeviceType.desktop;
    } else if (constraints.maxWidth >= 768) {
      return DeviceType.tablet;
    } else {
      return DeviceType.mobile;
    }
  }
}

enum DeviceType { mobile, tablet, desktop }

class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final EdgeInsets? mobilePadding;
  final EdgeInsets? tabletPadding;
  final EdgeInsets? desktopPadding;

  const ResponsivePadding({
    super.key,
    required this.child,
    this.mobilePadding,
    this.tabletPadding,
    this.desktopPadding,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, constraints, deviceType) {
        EdgeInsets padding;
        switch (deviceType) {
          case DeviceType.mobile:
            padding = mobilePadding ?? const EdgeInsets.all(16);
            break;
          case DeviceType.tablet:
            padding = tabletPadding ?? const EdgeInsets.all(24);
            break;
          case DeviceType.desktop:
            padding = desktopPadding ?? const EdgeInsets.all(32);
            break;
        }
        return Padding(padding: padding, child: child);
      },
    );
  }
}

class ResponsiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final double? mobileSize;
  final double? tabletSize;
  final double? desktopSize;
  final TextAlign? textAlign;
  final FontWeight? fontWeight;
  final Color? color;

  const ResponsiveText(
    this.text, {
    super.key,
    this.style,
    this.mobileSize,
    this.tabletSize,
    this.desktopSize,
    this.textAlign,
    this.fontWeight,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, constraints, deviceType) {
        double fontSize;
        switch (deviceType) {
          case DeviceType.mobile:
            fontSize = mobileSize ?? 14;
            break;
          case DeviceType.tablet:
            fontSize = tabletSize ?? 16;
            break;
          case DeviceType.desktop:
            fontSize = desktopSize ?? 18;
            break;
        }

        return Text(
          text,
          textAlign: textAlign,
          style: (style ?? const TextStyle()).copyWith(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: color,
          ),
        );
      },
    );
  }
}

class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final double spacing;
  final double runSpacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, constraints, deviceType) {
        int columns;
        switch (deviceType) {
          case DeviceType.mobile:
            columns = mobileColumns;
            break;
          case DeviceType.tablet:
            columns = tabletColumns;
            break;
          case DeviceType.desktop:
            columns = desktopColumns;
            break;
        }

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          crossAxisSpacing: spacing,
          mainAxisSpacing: runSpacing,
          childAspectRatio: 1,
          children: children,
        );
      },
    );
  }
}

class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsets? padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth ?? 1200),
        padding: padding,
        child: child,
      ),
    );
  }
}
