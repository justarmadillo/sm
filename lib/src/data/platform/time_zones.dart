/// Named home-timezone support for scheduling.
///
/// Scheduler decisions never consult the machine's current zone. The persisted
/// home-zone identifier is resolved against the bundled IANA database, which
/// keeps travel from changing the collection's StudyDay. Windows identifiers
/// are mapped through Unicode CLDR's territory-independent (`001`) mapping.
library;

import 'package:meta/meta.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/scheduling/study_day.dart';

/// Raised when persisted settings name no bundled IANA zone or known Windows
/// alias.
final class UnknownTimeZoneException implements Exception {
  const UnknownTimeZoneException(this.zoneId);

  final String zoneId;

  @override
  String toString() => 'Unknown home timezone: "$zoneId"';
}

/// Rules backed by the pinned IANA database bundled with the application.
@immutable
final class NamedTimeZone implements TimeZoneRules {
  const NamedTimeZone._(this._location);

  final tz.Location _location;

  @override
  String get zoneId => _location.name;

  @override
  int offsetMinutesAt(DateTime instantUtc) => tz.TZDateTime.from(
    instantUtc.toUtc(),
    _location,
  ).timeZoneOffset.inMinutes;
}

bool _timeZonesInitialized = false;

void _ensureTimeZonesInitialized() {
  if (_timeZonesInitialized) return;
  tz_data.initializeTimeZones();
  _timeZonesInitialized = true;
}

/// Converts either an IANA name or a mapped Windows name to the canonical IANA
/// identifier used in StudyDay values.
///
/// Unknown identifiers fail closed. In particular, `system` and numeric fixed
/// offsets are not accepted: either would make DST/travel behavior depend on
/// something other than the persisted named home zone.
String canonicalTimeZoneId(String zoneId) {
  _ensureTimeZonesInitialized();
  final String id = zoneId.trim();
  if (id.isEmpty) throw UnknownTimeZoneException(zoneId);

  final String? mapped = _windowsToIana[id.toLowerCase()];
  final String candidate = mapped ?? id;
  if (candidate == 'UTC') return candidate;
  if (!tz.timeZoneDatabase.locations.containsKey(candidate)) {
    throw UnknownTimeZoneException(zoneId);
  }
  return candidate;
}

/// Builds the offset rules named by persisted settings.
TimeZoneRules resolveTimeZone(String zoneId) {
  final String canonical = canonicalTimeZoneId(zoneId);
  if (canonical == 'UTC') return FixedOffsetZone.utc;
  return NamedTimeZone._(tz.getLocation(canonical));
}

/// IANA identifiers offered by Settings. Numeric `Etc/GMT` entries and legacy
/// aliases are intentionally omitted; persisted Windows identifiers remain
/// accepted by [resolveTimeZone].
List<String> get selectableZoneIds {
  return _selectableZoneIds;
}

final List<String> _selectableZoneIds = _buildSelectableZoneIds();

List<String> _buildSelectableZoneIds() {
  _ensureTimeZonesInitialized();
  final List<String> result = <String>[
    'UTC',
    ...tz.timeZoneDatabase.locations.keys.where(
      (String id) =>
          id.contains('/') &&
          !id.startsWith('Etc/') &&
          !id.startsWith('SystemV/') &&
          !id.startsWith('US/'),
    ),
  ]..sort();
  return List<String>.unmodifiable(result);
}

/// The CLDR Windows aliases accepted by [resolveTimeZone], exposed so mapping
/// completeness can be verified against the bundled database.
Map<String, String> get windowsTimeZoneMappings => _windowsToIana;

/// Unicode CLDR `windowsZones.xml`, `territory="001"` mappings.
///
/// Keep this table versioned with the pinned timezone dependency. Territory-
/// specific Windows mappings are deliberately not guessed because settings do
/// not currently persist a territory alongside the Windows identifier.
const Map<String, String> _windowsToIana = <String, String>{
  'dateline standard time': 'Etc/GMT+12',
  'utc-11': 'Etc/GMT+11',
  'aleutian standard time': 'America/Adak',
  'hawaiian standard time': 'Pacific/Honolulu',
  'marquesas standard time': 'Pacific/Marquesas',
  'alaskan standard time': 'America/Anchorage',
  'utc-09': 'Etc/GMT+9',
  'pacific standard time (mexico)': 'America/Tijuana',
  'utc-08': 'Etc/GMT+8',
  'pacific standard time': 'America/Los_Angeles',
  'us mountain standard time': 'America/Phoenix',
  'mountain standard time (mexico)': 'America/Mazatlan',
  'mountain standard time': 'America/Denver',
  'yukon standard time': 'America/Whitehorse',
  'central america standard time': 'America/Guatemala',
  'central standard time': 'America/Chicago',
  'easter island standard time': 'Pacific/Easter',
  'central standard time (mexico)': 'America/Mexico_City',
  'canada central standard time': 'America/Regina',
  'sa pacific standard time': 'America/Bogota',
  'eastern standard time (mexico)': 'America/Cancun',
  'eastern standard time': 'America/New_York',
  'haiti standard time': 'America/Port-au-Prince',
  'cuba standard time': 'America/Havana',
  'us eastern standard time': 'America/Indiana/Indianapolis',
  'turks and caicos standard time': 'America/Grand_Turk',
  'paraguay standard time': 'America/Asuncion',
  'atlantic standard time': 'America/Halifax',
  'venezuela standard time': 'America/Caracas',
  'central brazilian standard time': 'America/Cuiaba',
  'sa western standard time': 'America/La_Paz',
  'pacific sa standard time': 'America/Santiago',
  'newfoundland standard time': 'America/St_Johns',
  'tocantins standard time': 'America/Araguaina',
  'e. south america standard time': 'America/Sao_Paulo',
  'sa eastern standard time': 'America/Cayenne',
  'argentina standard time': 'America/Argentina/Buenos_Aires',
  'greenland standard time': 'America/Nuuk',
  'montevideo standard time': 'America/Montevideo',
  'magallanes standard time': 'America/Punta_Arenas',
  'saint pierre standard time': 'America/Miquelon',
  'bahia standard time': 'America/Bahia',
  'utc-02': 'Etc/GMT+2',
  'azores standard time': 'Atlantic/Azores',
  'cape verde standard time': 'Atlantic/Cape_Verde',
  'utc': 'UTC',
  'gmt standard time': 'Europe/London',
  'greenwich standard time': 'Atlantic/Reykjavik',
  'sao tome standard time': 'Africa/Sao_Tome',
  'morocco standard time': 'Africa/Casablanca',
  'w. europe standard time': 'Europe/Berlin',
  'central europe standard time': 'Europe/Budapest',
  'romance standard time': 'Europe/Paris',
  'central european standard time': 'Europe/Warsaw',
  'w. central africa standard time': 'Africa/Lagos',
  'jordan standard time': 'Asia/Amman',
  'gtb standard time': 'Europe/Bucharest',
  'middle east standard time': 'Asia/Beirut',
  'egypt standard time': 'Africa/Cairo',
  'e. europe standard time': 'Europe/Chisinau',
  'syria standard time': 'Asia/Damascus',
  'west bank standard time': 'Asia/Hebron',
  'south africa standard time': 'Africa/Johannesburg',
  'fle standard time': 'Europe/Kyiv',
  'israel standard time': 'Asia/Jerusalem',
  'south sudan standard time': 'Africa/Juba',
  'kaliningrad standard time': 'Europe/Kaliningrad',
  'sudan standard time': 'Africa/Khartoum',
  'libya standard time': 'Africa/Tripoli',
  'namibia standard time': 'Africa/Windhoek',
  'arabic standard time': 'Asia/Baghdad',
  'turkey standard time': 'Europe/Istanbul',
  'arab standard time': 'Asia/Riyadh',
  'belarus standard time': 'Europe/Minsk',
  'russian standard time': 'Europe/Moscow',
  'e. africa standard time': 'Africa/Nairobi',
  'iran standard time': 'Asia/Tehran',
  'arabian standard time': 'Asia/Dubai',
  'astrakhan standard time': 'Europe/Astrakhan',
  'azerbaijan standard time': 'Asia/Baku',
  'russia time zone 3': 'Europe/Samara',
  'mauritius standard time': 'Indian/Mauritius',
  'saratov standard time': 'Europe/Saratov',
  'georgian standard time': 'Asia/Tbilisi',
  'volgograd standard time': 'Europe/Volgograd',
  'caucasus standard time': 'Asia/Yerevan',
  'afghanistan standard time': 'Asia/Kabul',
  'west asia standard time': 'Asia/Tashkent',
  'ekaterinburg standard time': 'Asia/Yekaterinburg',
  'pakistan standard time': 'Asia/Karachi',
  'qyzylorda standard time': 'Asia/Qyzylorda',
  'india standard time': 'Asia/Kolkata',
  'sri lanka standard time': 'Asia/Colombo',
  'nepal standard time': 'Asia/Kathmandu',
  'central asia standard time': 'Asia/Bishkek',
  'bangladesh standard time': 'Asia/Dhaka',
  'omsk standard time': 'Asia/Omsk',
  'myanmar standard time': 'Asia/Yangon',
  'se asia standard time': 'Asia/Bangkok',
  'altai standard time': 'Asia/Barnaul',
  'w. mongolia standard time': 'Asia/Hovd',
  'north asia standard time': 'Asia/Krasnoyarsk',
  'n. central asia standard time': 'Asia/Novosibirsk',
  'tomsk standard time': 'Asia/Tomsk',
  'china standard time': 'Asia/Shanghai',
  'north asia east standard time': 'Asia/Irkutsk',
  'singapore standard time': 'Asia/Singapore',
  'w. australia standard time': 'Australia/Perth',
  'taipei standard time': 'Asia/Taipei',
  'ulaanbaatar standard time': 'Asia/Ulaanbaatar',
  'aus central w. standard time': 'Australia/Eucla',
  'transbaikal standard time': 'Asia/Chita',
  'tokyo standard time': 'Asia/Tokyo',
  'north korea standard time': 'Asia/Pyongyang',
  'korea standard time': 'Asia/Seoul',
  'yakutsk standard time': 'Asia/Yakutsk',
  'cen. australia standard time': 'Australia/Adelaide',
  'aus central standard time': 'Australia/Darwin',
  'e. australia standard time': 'Australia/Brisbane',
  'aus eastern standard time': 'Australia/Sydney',
  'west pacific standard time': 'Pacific/Port_Moresby',
  'tasmania standard time': 'Australia/Hobart',
  'vladivostok standard time': 'Asia/Vladivostok',
  'lord howe standard time': 'Australia/Lord_Howe',
  'bougainville standard time': 'Pacific/Bougainville',
  'russia time zone 10': 'Asia/Srednekolymsk',
  'magadan standard time': 'Asia/Magadan',
  'norfolk standard time': 'Pacific/Norfolk',
  'sakhalin standard time': 'Asia/Sakhalin',
  'central pacific standard time': 'Pacific/Guadalcanal',
  'russia time zone 11': 'Asia/Kamchatka',
  'new zealand standard time': 'Pacific/Auckland',
  'utc+12': 'Etc/GMT-12',
  'fiji standard time': 'Pacific/Fiji',
  'chatham islands standard time': 'Pacific/Chatham',
  'utc+13': 'Etc/GMT-13',
  'tonga standard time': 'Pacific/Tongatapu',
  'samoa standard time': 'Pacific/Apia',
  'line islands standard time': 'Pacific/Kiritimati',
};
