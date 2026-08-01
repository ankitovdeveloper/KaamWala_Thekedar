/// Native builds ship the key in the Android manifest / iOS plist, so the SDK
/// is already available by the time any map is built.
Future<void> ensureMapsLoaded(String apiKey) async {}
