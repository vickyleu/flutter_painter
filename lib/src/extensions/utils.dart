extension ObjectExt<T> on T {
  R let<R>(R Function(T that) op) => op(this);

  T apply(void Function(T that) op) {
    op.call(this);
    return this;
  }

}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1).toLowerCase()}";
  }
}
