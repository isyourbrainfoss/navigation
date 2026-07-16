enum ThemePreference { system, light, dark }

enum MapStylePreference { auto, light, dark }

class AppSettings {
  const AppSettings({
    this.theme = ThemePreference.system,
    this.mapStyle = MapStylePreference.auto,
    this.metricUnits = true,
    this.courseUp = true,
    this.followOnStart = true,
  });

  final ThemePreference theme;
  final MapStylePreference mapStyle;
  final bool metricUnits;
  final bool courseUp;
  final bool followOnStart;

  static const defaults = AppSettings();

  AppSettings copyWith({
    ThemePreference? theme,
    MapStylePreference? mapStyle,
    bool? metricUnits,
    bool? courseUp,
    bool? followOnStart,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      mapStyle: mapStyle ?? this.mapStyle,
      metricUnits: metricUnits ?? this.metricUnits,
      courseUp: courseUp ?? this.courseUp,
      followOnStart: followOnStart ?? this.followOnStart,
    );
  }

  Map<String, dynamic> toJson() => {
        'theme': theme.name,
        'mapStyle': mapStyle.name,
        'metricUnits': metricUnits,
        'courseUp': courseUp,
        'followOnStart': followOnStart,
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
    return AppSettings(
      theme: theme,
      mapStyle: mapStyle,
      metricUnits: json['metricUnits'] as bool? ?? true,
      courseUp: json['courseUp'] as bool? ?? true,
      followOnStart: json['followOnStart'] as bool? ?? true,
    );
  }
}
