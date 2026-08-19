/// Normalizes free-typed website input (`https://www.examplebet.com/path`,
/// `WWW.EXAMPLEBET.COM`, `examplebet.com`) down to the bare, lowercase host
/// `DomainBlocklist.kt` expects as a `blocked_domains` doc ID
/// (android/app/.../vpn/DomainBlocklist.kt) — no scheme, no port, no path,
/// no leading `www.`. Stripping `www.` is deliberate, not cosmetic:
/// `DomainBlocklist.isBlocked()` already matches subdomains via
/// `host.endsWith(".$blockedDomain")`, so storing the bare apex domain
/// blocks `www.<domain>` (and any other subdomain) for free, whereas
/// storing `www.<domain>` verbatim would NOT block the bare apex domain.
///
/// Returns null if [input] doesn't look like a usable domain.
String? normalizeDomain(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  final candidate = trimmed.contains('://') ? trimmed : 'https://$trimmed';
  Uri uri;
  try {
    uri = Uri.parse(candidate);
  } catch (_) {
    return null;
  }

  var host = uri.host.toLowerCase();
  if (host.startsWith('www.')) host = host.substring(4);

  return isValidDomain(host) ? host : null;
}

/// At least two labels (`example.com`, not just `example`), each label
/// alphanumeric/hyphen (no leading/trailing hyphen), no spaces or other
/// invalid characters. Deliberately simple — this is UX validation to catch
/// typos, not full RFC 1035 compliance.
final _domainPattern = RegExp(
  r'^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$',
);

bool isValidDomain(String host) => _domainPattern.hasMatch(host);
