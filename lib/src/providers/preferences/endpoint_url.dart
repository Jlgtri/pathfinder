part of '../../providers.dart';

/// The currently selected enpoint [Uri].
///
/// Stored in [SharedPreferences] as url string.
@Riverpod(keepAlive: true, dependencies: <Object>[preferences])
class EndpointUrlNotifier extends _$EndpointUrlNotifier {
  late final SharedPreferencesAsync _preferences;

  @override
  Future<Uri?> build() async {
    _preferences = ref.read(preferencesProvider);
    return await _preferences.readEndpointUrl();
  }

  /// Set [AppTheme].
  Future<void> set(Uri? uri) async {
    await _preferences.updateEndpointUrl(uri);
    state = AsyncValue<Uri?>.data(uri);
  }
}

extension on SharedPreferencesAsync {
  static const String key = 'api_endpoint';

  Future<Uri?> readEndpointUrl() async {
    final String? url = await getString(key);
    if (url == null) {
      return null;
    }
    return Uri.parse(url);
  }

  Future<void> updateEndpointUrl(Uri? uri) =>
      uri == null ? remove(key) : setString(key, uri.toString());
}

final RegExp _invalidCharacters = RegExp(r'\s|[\x00-\x1F\x7F]');

final RegExp _invalidEncoding = RegExp('%(?![0-9a-fA-F]{2})');

final RegExp _domainLabel = RegExp(
  r'^[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$',
);
final RegExp _ipv4Pattern = RegExp(r'^\d+\.\d+\.\d+\.\d+$');

Uri? parseUrl(String value) {
  final String input = value.trim();

  if (input.isEmpty ||
      _invalidCharacters.hasMatch(input) ||
      _invalidEncoding.hasMatch(input)) {
    return null;
  }

  final Uri? uri = Uri.tryParse(input);

  if (uri == null ||
      !uri.hasAuthority ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty ||
      uri.hasFragment ||
      uri.authority.contains('@')) {
    return null;
  }

  if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) {
    return null;
  }

  final String host = uri.host;

  // IPv6
  if (host.contains(':')) {
    try {
      Uri.parseIPv6Address(host);
      return uri;
    } on FormatException {
      return null;
    }
  }

  // IPv4
  if (_ipv4Pattern.hasMatch(host)) {
    final List<String> octets = host.split('.');

    final bool valid = octets.every((String octet) {
      final int? value = int.tryParse(octet);

      return value != null &&
          value >= 0 &&
          value <= 255 &&
          (octet.length == 1 || !octet.startsWith('0'));
    });

    return valid ? uri : null;
  }

  // Domain / localhost
  if (host.length > 253) return null;

  final List<String> labels = host.split('.');

  if (labels.any((String label) => !_domainLabel.hasMatch(label))) {
    return null;
  }

  return uri;
}
