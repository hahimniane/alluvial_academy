/// Service providing mock company and admin information for invoices.
/// This can be easily replaced later with real data from Firestore settings.
class MockCompanyService {
  /// Company information model
  static CompanyInfo getCompanyInfo() {
    return const CompanyInfo(
      name: 'Alluwal Education Hub',
      address: 'Lacey',
      city: 'Lacey',
      state: 'Washington State',
      country: 'United States of America',
      phone: '+1646-338-1286',
      email: 'alluwhalacademy@gmail.com',
    );
  }

  /// Admin information for "Received by" field
  static AdminInfo getAdminInfo() {
    return const AdminInfo(
      name: 'Muhammed Barry',
      signature: '', // For future use with signature images
    );
  }
}

/// Company information data model
class CompanyInfo {
  final String name;
  final String address;
  final String city;
  final String state;
  final String country;
  final String phone;
  final String email;

  const CompanyInfo({
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    required this.country,
    required this.phone,
    required this.email,
  });

  /// Full address as a single string
  String get fullAddress => '$address, $city, $state, $country';

  /// Contact information formatted
  String get contactInfo => 'Contact: $phone\nEmail: $email';
}

/// Admin information data model
class AdminInfo {
  final String name;
  final String signature; // For future use with signature images

  const AdminInfo({
    required this.name,
    this.signature = '',
  });
}

