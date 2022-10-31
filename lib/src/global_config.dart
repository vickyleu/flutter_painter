import 'package:flutter/cupertino.dart';

class GlobalConfig{

  bool isOverlayShowing = false;

  GlobalConfig._();

  static GlobalConfig? of(BuildContext context) {
    try{
      final result = GlobalConfigWidget.of(context);
      return result.config;
    }catch(e){
    }
  }

}


class GlobalConfigWidget extends InheritedWidget{
  GlobalConfigWidget({
    Key? key,
    required Widget child,
  }) : super(key: key, child: child);

  final GlobalConfig config = GlobalConfig._();

  static GlobalConfigWidget of(BuildContext context) {
    final GlobalConfigWidget? result =
    context.dependOnInheritedWidgetOfExactType<GlobalConfigWidget>();
    assert(result != null, 'No GlobalConfigWidget found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(GlobalConfigWidget oldWidget) {
    return config != oldWidget.config;
  }
}
