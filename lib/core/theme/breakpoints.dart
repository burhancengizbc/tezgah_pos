import 'package:flutter/widgets.dart';

enum DeviceClass { phone, tablet, desktop }

class Breakpoints {
  static DeviceClass of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1100) {
      return DeviceClass.desktop;
    } else if (width >= 760) {
      return DeviceClass.tablet;
    } else {
      return DeviceClass.phone;
    }
  }
}