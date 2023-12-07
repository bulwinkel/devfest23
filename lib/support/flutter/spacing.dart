import 'package:flutter/widgets.dart';

const spacer = Spacer();

extension PtX on num {
  double get pt => this * 4.0;
}

extension SpacerX on int {
  Spacer get spacer => Spacer(flex: this);
}

extension BoxX on num {
  SizedBox get box => SizedBox(
        width: toDouble(),
        height: toDouble(),
      );
}

extension PaddingX on double {
  EdgeInsetsGeometry get all => EdgeInsets.all(this);
  EdgeInsetsGeometry get horizontal => EdgeInsets.symmetric(horizontal: this);
  EdgeInsetsGeometry get vertical => EdgeInsets.symmetric(vertical: this);
  EdgeInsetsGeometry get left => EdgeInsets.only(left: this);
  EdgeInsetsGeometry get right => EdgeInsets.only(right: this);
  EdgeInsetsGeometry get top => EdgeInsets.only(top: this);
  EdgeInsetsGeometry get bottom => EdgeInsets.only(bottom: this);
  EdgeInsetsGeometry get onlyLeft => EdgeInsets.only(left: this);
  EdgeInsetsGeometry get onlyRight => EdgeInsets.only(right: this);
  EdgeInsetsGeometry get onlyTop => EdgeInsets.only(top: this);
  EdgeInsetsGeometry get onlyBottom => EdgeInsets.only(bottom: this);
}
