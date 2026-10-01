/// WHO USUALLY BUYS FROM A BUSINESS OF THIS KIND (setup, "Who you want").
///
/// The buyer list used to open on every industry from A to Z, so a roofer was
/// asked to find "Property managers" among "Aviation" and "Biotech". These are
/// the first few kinds of buyer a business of each kind usually sells to,
/// offered as one-tap suggestions above the full list. They are only
/// suggestions: the owner picks, removes or types their own.
const Map<String, List<String>> buyerSuggestionsByIndustry = {
  'accounting_finance': ['Small businesses', 'Restaurants', 'Medical practices', 'Contractors', 'Nonprofits'],
  'architecture_design': ['Property developers', 'Real estate investors', 'Restaurants', 'Schools', 'Homeowners associations'],
  'automotive': ['Fleet operators', 'Car dealerships', 'Delivery companies', 'Rental agencies'],
  'construction': ['Property managers', 'Real estate developers', 'Homeowners associations', 'General contractors', 'Schools'],
  'consulting': ['Small businesses', 'Manufacturers', 'Healthcare providers', 'Nonprofits'],
  'cybersecurity': ['Law firms', 'Medical practices', 'Accounting firms', 'Small businesses'],
  'education': ['Schools', 'Employers', 'Nonprofits', 'Local governments'],
  'engineering': ['Property developers', 'Manufacturers', 'Local governments', 'General contractors'],
  'events_hospitality': ['Corporate offices', 'Nonprofits', 'Wedding planners', 'Schools'],
  'food_beverage': ['Restaurants', 'Cafes', 'Grocery stores', 'Hotels', 'Caterers'],
  'healthcare_medical': ['Employers', 'Schools', 'Senior living communities', 'Clinics'],
  'home_services': ['Property managers', 'Homeowners associations', 'Real estate agents', 'Landlords'],
  'hr_recruiting': ['Small businesses', 'Restaurants', 'Manufacturers', 'Healthcare providers'],
  'industrial_manufacturing': ['Distributors', 'Contractors', 'Retailers', 'Manufacturers'],
  'insurance': ['Small businesses', 'Contractors', 'Restaurants', 'Property managers'],
  'legal_services': ['Small businesses', 'Real estate agents', 'Contractors', 'Startups'],
  'logistics_supply_chain': ['Manufacturers', 'Retailers', 'Distributors', 'E-commerce stores'],
  'marketing_advertising': ['Restaurants', 'Dental practices', 'Law firms', 'Real estate agents', 'Gyms'],
  'professional_services': ['Small businesses', 'Law firms', 'Medical practices', 'Real estate agents'],
  'real_estate': ['Property investors', 'Landlords', 'Small businesses', 'Developers'],
  'saas_software': ['Small businesses', 'Agencies', 'Clinics', 'Retailers'],
  'security_facilities': ['Property managers', 'Office buildings', 'Retailers', 'Schools', 'Warehouses'],
  'sports_fitness': ['Corporate offices', 'Schools', 'Community centers'],
  'transportation': ['Manufacturers', 'Retailers', 'Event organisers', 'Schools'],
};

/// Suggestions for [industryCode] not already chosen, or none.
List<String> buyerSuggestionsFor(String? industryCode, Iterable<String> chosen) {
  final taken = chosen.map((c) => c.toLowerCase()).toSet();
  return [
    for (final s in buyerSuggestionsByIndustry[industryCode] ?? const <String>[])
      if (!taken.contains(s.toLowerCase())) s,
  ];
}
