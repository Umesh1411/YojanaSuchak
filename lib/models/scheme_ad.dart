class SchemeAd {
  final String title;
  final String emoji;
  final List<String> keyPoints;
  final String officialApplyLink;

  const SchemeAd({
    required this.title,
    required this.emoji,
    required this.keyPoints,
    required this.officialApplyLink,
  });

  /// Hardcoded list of real featured schemes for the demo
  static List<SchemeAd> get featuredSchemes => const [
        SchemeAd(
          title: 'PM Surya Ghar – Rooftop Solar',
          emoji: '☀️',
          keyPoints: [
            'Get ₹30,000–₹78,000 subsidy',
            'Free electricity up to 300 units/month',
            'For households with rooftop space',
          ],
          officialApplyLink: 'https://pmsuryaghar.gov.in',
        ),
        SchemeAd(
          title: 'Solar Pump Scheme (Farmers)',
          emoji: '🌾',
          keyPoints: [
            'Up to 95% subsidy for solar pumps',
            'No diesel cost for irrigation',
            'For farmers with land',
          ],
          officialApplyLink: 'https://mahadiscom.in/solar/',
        ),
        SchemeAd(
          title: 'PM SVANidhi (Street Vendors)',
          emoji: '💼',
          keyPoints: [
            '₹10,000–₹50,000 working capital loan',
            'Digital cashback incentives',
            'For urban street vendors',
          ],
          officialApplyLink: 'https://pmsvanidhi.mohua.gov.in',
        ),
        SchemeAd(
          title: 'National Scholarship Portal',
          emoji: '🎓',
          keyPoints: [
            'Scholarships for students',
            'Covers central & state schemes',
            'Easy online application',
          ],
          officialApplyLink: 'https://scholarships.gov.in',
        ),
        SchemeAd(
          title: 'AMRUT Mission (Urban Dev)',
          emoji: '🏙️',
          keyPoints: [
            'Water supply & sewerage improvement',
            'Urban green spaces development',
            'Better infrastructure for cities',
          ],
          officialApplyLink: 'https://mohua.gov.in/cms/amrut.php',
        ),
        SchemeAd(
          title: 'Nagar Van Yojana',
          emoji: '🌳',
          keyPoints: [
            'Development of city forests',
            'Improve air quality & biodiversity',
            'For urban local bodies',
          ],
          officialApplyLink: 'https://moef.gov.in/en/division/national-mission-for-a-green-india/',
        ),
      ];
}
