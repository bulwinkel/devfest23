import 'package:flutter_hooks/flutter_hooks.dart';

({
  Null Function(T item) add,
  Null Function() clear,
  List<T> Function() get,
  Null Function(T item) remove,
  Null Function(bool Function(T p1) selector, T Function(T p1) update) update
}) useList<T>(List<T> initialValue) {
  final list = useState(initialValue);

  final add = useCallback((T item) {
    list.value = [...list.value, item];
  }, [list.value]);

  final remove = useCallback((T item) {
    list.value = list.value.where((i) => i != item).toList();
  }, [list.value]);

  final update = useCallback((
    bool Function(T) selector,
    T Function(T) update,
  ) {
    list.value = list.value.map((i) {
      if (selector(i)) {
        return update(i);
      } else {
        return i;
      }
    }).toList();
  }, [list.value]);

  final clear = useCallback(() {
    list.value = [];
  }, [list.value]);

  return (
    get: () => list.value,
    add: add,
    update: update,
    remove: remove,
    clear: clear,
  );
}
