class AcademyProfile {
  final String name;
  final String? logoPath; // local path da imagem

  AcademyProfile({
    required this.name,
    this.logoPath,
  });

  AcademyProfile copyWith({
    String? name,
    String? logoPath,
  }) {
    return AcademyProfile(
      name: name ?? this.name,
      logoPath: logoPath ?? this.logoPath,
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
