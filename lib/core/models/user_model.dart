class UserModel {
  final String id;
  final String email;
  final String name;
  final String accountType; // 'artist' | 'agency'
  final String? artistId;
  final bool onboardingCompleted;
  final String? token;
  final String? plan;
  final String? birthDate;
  final int sparksBalance;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.accountType,
    this.artistId,
    this.onboardingCompleted = false,
    this.token,
    this.plan,
    this.birthDate,
    this.sparksBalance = 0,
  });

  bool get isAgency => accountType == 'agency';
  bool get isArtist => accountType == 'artist';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      accountType: json['account_type']?.toString() ?? 'artist',
      artistId: json['artist_id']?.toString(),
      onboardingCompleted: json['onboarding_completed'] == true,
      token: json['token']?.toString(),
      plan: json['plan']?.toString(),
      birthDate: json['birth_date']?.toString(),
      sparksBalance: (json['sparks_balance'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'account_type': accountType,
        'artist_id': artistId,
        'onboarding_completed': onboardingCompleted,
        'token': token,
        'plan': plan,
        'birth_date': birthDate,
        'sparks_balance': sparksBalance,
      };

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? accountType,
    String? artistId,
    bool? onboardingCompleted,
    String? token,
    String? plan,
    String? birthDate,
    int? sparksBalance,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      accountType: accountType ?? this.accountType,
      artistId: artistId ?? this.artistId,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      token: token ?? this.token,
      plan: plan ?? this.plan,
      birthDate: birthDate ?? this.birthDate,
      sparksBalance: sparksBalance ?? this.sparksBalance,
    );
  }
}

