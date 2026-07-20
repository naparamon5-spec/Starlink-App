class AppVersion {
  final int major;
  final int minor;
  final int patch;

  AppVersion(this.major, this.minor, this.patch);

  factory AppVersion.fromString(String version) {
    final parts = version.split('.').map(int.parse).toList();
    return AppVersion(parts[0], parts[1], parts[2]);
  }

  bool isOutdated(AppVersion other) {
    if (major < other.major) return true;
    if (major > other.major) return false;
    if (minor < other.minor) return true;
    if (minor > other.minor) return false;
    return patch < other.patch;
  }

  @override
  String toString() => '$major.$minor.$patch';
}
