class AcademyBranding {
  final String logoAssetKey;
  final String loginBackgroundAssetKey;
  final String logoUrl;
  final String loginBackgroundUrl;
  final String primaryColor;
  final String secondaryColor;

  const AcademyBranding({
    this.logoAssetKey = '',
    this.loginBackgroundAssetKey = '',
    this.logoUrl = '',
    this.loginBackgroundUrl = '',
    this.primaryColor = '',
    this.secondaryColor = '',
  });

  factory AcademyBranding.fromMap(Map<String, dynamic>? map) {
    final data = map ?? const <String, dynamic>{};
    return AcademyBranding(
      logoAssetKey: (data['logoAssetKey'] ?? '').toString().trim(),
      loginBackgroundAssetKey:
          (data['loginBackgroundAssetKey'] ?? '').toString().trim(),
      logoUrl: (data['logoUrl'] ?? '').toString().trim(),
      loginBackgroundUrl: (data['loginBackgroundUrl'] ?? '').toString().trim(),
      primaryColor: (data['primaryColor'] ?? '').toString().trim(),
      secondaryColor: (data['secondaryColor'] ?? '').toString().trim(),
    );
  }

  bool get hasLogo => logoUrl.isNotEmpty || logoAssetKey.isNotEmpty;
  bool get hasLoginBackground =>
      loginBackgroundUrl.isNotEmpty || loginBackgroundAssetKey.isNotEmpty;
  bool get hasColors => primaryColor.isNotEmpty || secondaryColor.isNotEmpty;
  bool get isEmpty => !hasLogo && !hasLoginBackground && !hasColors;
}

class AcademyProfile {
  final String name;
  final String? logoPath;
  final AcademyBranding branding;

  AcademyProfile({
    required this.name,
    this.logoPath,
    this.branding = const AcademyBranding(),
  });

  factory AcademyProfile.fromMap(String academyId, Map<String, dynamic> map) {
    final brandingData = map['branding'];
    return AcademyProfile(
      name: (map['name'] ?? map['academyName'] ?? academyId).toString().trim(),
      branding: AcademyBranding.fromMap(
        brandingData is Map ? Map<String, dynamic>.from(brandingData) : null,
      ),
    );
  }

  AcademyProfile copyWith({
    String? name,
    String? logoPath,
    AcademyBranding? branding,
  }) {
    return AcademyProfile(
      name: name ?? this.name,
      logoPath: logoPath ?? this.logoPath,
      branding: branding ?? this.branding,
    );
  }
}

abstract class IAcademyRepository {
  Future<AcademyProfile> get();
  Future<void> save(AcademyProfile profile);
}

class InMemoryAcademyRepository implements IAcademyRepository {
  AcademyProfile _profile = AcademyProfile(name: 'Titans BJJ');

  @override
  Future<AcademyProfile> get() async => _profile;

  @override
  Future<void> save(AcademyProfile profile) async {
    _profile = profile;
  }
}
