enum ThemePreference { system, light, dark }

enum MapStylePreference { auto, light, dark, topo, cycle }

enum NightDriving { off, auto, on }

class AppSettings {
  const AppSettings({
    this.theme = ThemePreference.system,
    this.mapStyle = MapStylePreference.auto,
    this.metricUnits = true,
    this.courseUp = true,
    this.followOnStart = true,
    this.voiceEnabled = true,
    this.keepScreenOn = true,
    this.rotationLock = false,
    this.nightDriving = NightDriving.auto,
    this.haptics = true,
    this.showSpeed = true,
    this.showScaleBar = true,
    this.largeHud = true,
    this.highContrast = false,
    this.customRoutingUrl = '',
  });

  final ThemePreference theme;
  final MapStylePreference mapStyle;
  final bool metricUnits;
  final bool courseUp;
  final bool followOnStart;
  final bool voiceEnabled;
  final bool keepScreenOn;
  final bool rotationLock;
  final NightDriving nightDriving;
  final bool haptics;
  final bool showSpeed;
  final bool showScaleBar;
  final bool largeHud;
  final bool highContrast;
  final String customRoutingUrl;

  static const defaults = AppSettings();

  AppSettings copyWith({
    ThemePreference? theme,
    MapStylePreference? mapStyle,
    bool? metricUnits,
    bool? courseUp,
    bool? followOnStart,
    bool? voiceEnabled,
    bool? keepScreenOn,
    bool? rotationLock,
    NightDriving? nightDriving,
    bool? haptics,
    bool? showSpeed,
    bool? showScaleBar,
    bool? largeHud,
    bool? highContrast,
    String? customRoutingUrl,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      mapStyle: mapStyle ?? this.mapStyle,
      metricUnits: metricUnits ?? this.metricUnits,
      courseUp: courseUp ?? this.courseUp,
      followOnStart: followOnStart ?? this.followOnStart,
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      rotationLock: rotationLock ?? this.rotationLock,
      nightDriving: nightDriving ?? this.nightDriving,
      haptics: haptics ?? this.haptics,
      showSpeed: showSpeed ?? this.showSpeed,
      showScaleBar: showScaleBar ?? this.showScaleBar,
      largeHud: largeHud ?? this.largeHud,
      highContrast: highContrast ?? this.highContrast,
      customRoutingUrl: customRoutingUrl ?? this.customRoutingUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'theme': theme.name,
        'mapStyle': mapStyle.name,
        'metricUnits': metricUnits,
        'courseUp': courseUp,
        'followOnStart': followOnStart,
        'voiceEnabled': voiceEnabled,
        'keepScreenOn': keepScreenOn,
        'rotationLock': rotationLock,
        'nightDriving': nightDriving.name,
        'haptics': haptics,
        'showSpeed': showSpeed,
        'showScaleBar': showScaleBar,
        'largeHud': largeHud,
        'highContrast': highContrast,
        'customRoutingUrl': customRoutingUrl,
      };

  factory AppSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    ThemePreference theme = ThemePreference.system;
    for (final t in ThemePreference.values) {
      if (t.name == json['theme']) theme = t;
    }
    MapStylePreference mapStyle = MapStylePreference.auto;
    for (final m in MapStylePreference.values) {
      if (m.name == json['mapStyle']) mapStyle = m;
    }
    NightDriving night = NightDriving.auto;
    for (final n in NightDriving.values) {
      if (n.name == json['nightDriving']) night = n;
    }
    return AppSettings(
      theme: theme,
      mapStyle: mapStyle,
      metricUnits: json['metricUnits'] as bool? ?? true,
      courseUp: json['courseUp'] as bool? ?? true,
      followOnStart: json['followOnStart'] as bool? ?? true,
      voiceEnabled: json['voiceEnabled'] as bool? ?? true,
      keepScreenOn: json['keepScreenOn'] as bool? ?? true,
      rotationLock: json['rotationLock'] as bool? ?? false,
      nightDriving: night,
      haptics: json['haptics'] as bool? ?? true,
      showSpeed: json['showSpeed'] as bool? ?? true,
      showScaleBar: json['showScaleBar'] as bool? ?? true,
      largeHud: json['largeHud'] as bool? ?? true,
      highContrast: json['highContrast'] as bool? ?? false,
      customRoutingUrl: json['customRoutingUrl'] as String? ?? '',
    );
  }
}
