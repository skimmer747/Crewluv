
//
//  AirportDataProvider.swift
//  CrewLuve
//
//  Simplified airport data provider for flight route visualization
//

import Foundation

/// Simplified airport information for route display
struct AirportData {
    let iata: String
    let city: String
    let country: String
    let latitude: Double
    let longitude: Double
}

/// Provider for airport location data used by FlightRouteMapView
class AirportDataProvider {
    static let shared = AirportDataProvider()

    private let airports: [String: AirportData]

    private init() {
        airports = Self.buildAirportDatabase()
    }

    /// Look up airport info by IATA code
    func airportInfo(forIataCode iataCode: String) -> AirportData? {
        airports[iataCode.uppercased()]
    }

    // MARK: - Airport Database

    /// Look up airport info by city name (returns all matches)
    func airportInfo(forCity city: String) -> [AirportData] {
        airports.values.filter { $0.city.caseInsensitiveCompare(city) == .orderedSame }
    }

    // MARK: - Airport Database
    private static func buildAirportDatabase() -> [String: AirportData] {
        let entries: [(String, String, String, Double, Double)] = [
            // UPS Hubs
            ("SDF", "Louisville", "USA", 38.1746, -85.7382),
            ("ANC", "Anchorage", "USA", 61.1744, -149.9983),
            ("PHL", "Philadelphia", "USA", 39.8721, -75.2407),
            ("ONT", "Ontario", "USA", 34.0560, -117.6012),
            ("DFW", "Dallas/Fort Worth", "USA", 32.8998, -97.0403),
            ("CAE", "Columbia", "USA", 33.9388, -81.1195),
            ("MIA", "Miami", "USA", 25.7959, -80.2871),
            ("RFD", "Rockford", "USA", 42.1954, -89.0972),
            ("GYY", "Gary", "USA", 41.6163, -87.4128),

            // International
            ("CGN", "Cologne", "Germany", 50.8659, 7.1427),
            ("HKG", "Hong Kong", "China", 22.3080, 113.9185),
            ("PVG", "Shanghai", "China", 31.1444, 121.8053),
            ("SZX", "Shenzhen", "China", 22.6393, 113.8109),
            ("EMA", "Derby", "UK", 52.8311, -1.3281),
            ("YHM", "Hamilton", "Canada", 43.1593, -79.9353),
            ("YMX", "Montreal", "Canada", 45.6797, -74.0387),
            ("NLU", "Mexico City", "Mexico", 19.7565, -99.0183),
            ("SJU", "San Juan", "Puerto Rico", 18.4394, -66.0018),

            // Major US
            ("ALB", "Albany", "USA", 42.7483, -73.8017),
            ("ATL", "Atlanta", "USA", 33.6407, -84.4277),
            ("AUS", "Austin", "USA", 30.1945, -97.6699),
            ("BDL", "Hartford", "USA", 41.9389, -72.6832),
            ("BFI", "Seattle", "USA", 47.5303, -122.3019),
            ("BHM", "Birmingham", "USA", 33.5639, -86.7522),
            ("BIL", "Billings", "USA", 45.8077, -108.5428),
            ("BNA", "Nashville", "USA", 36.1263, -86.6775),
            ("BOI", "Boise", "USA", 43.5644, -116.2228),
            ("BOS", "Boston", "USA", 42.3656, -71.0096),
            ("BUF", "Buffalo", "USA", 42.9405, -78.7322),
            ("BWI", "Baltimore", "USA", 39.1774, -76.6684),
            ("CLE", "Cleveland", "USA", 41.4117, -81.8500),
            ("CLT", "Charlotte", "USA", 35.2144, -80.9473),
            ("CVG", "Cincinnati", "USA", 39.0489, -84.6678),
            ("DEN", "Denver", "USA", 39.8561, -104.6737),
            ("DSM", "Des Moines", "USA", 41.5340, -93.6631),
            ("DTW", "Detroit", "USA", 42.2124, -83.3534),
            ("ELP", "El Paso", "USA", 31.8072, -106.3778),
            ("EWR", "Newark", "USA", 40.6895, -74.1745),
            ("FAT", "Fresno", "USA", 36.7758, -119.7181),
            ("GEG", "Spokane", "USA", 47.6199, -117.5339),
            ("GSO", "Greensboro", "USA", 36.0978, -79.9395),
            ("GSP", "Greenville", "USA", 34.8957, -82.2189),
            ("HNL", "Honolulu", "USA", 21.3245, -157.9251),
            ("HSV", "Huntsville", "USA", 34.6372, -86.7750),
            ("IAD", "Washington DC", "USA", 38.9445, -77.4558),
            ("IAH", "Houston", "USA", 29.9844, -95.3414),
            ("ICT", "Wichita", "USA", 37.6499, -97.4331),
            ("IND", "Indianapolis", "USA", 39.7169, -86.2944),
            ("JAN", "Jackson", "USA", 32.3112, -90.0759),
            ("JAX", "Jacksonville", "USA", 30.4941, -81.6879),
            ("JFK", "New York", "USA", 40.6413, -73.7781),
            ("KOA", "Kona", "USA", 19.7388, -156.0456),
            ("LAN", "Lansing", "USA", 42.7787, -84.5874),
            ("LAS", "Las Vegas", "USA", 36.0840, -115.1537),
            ("LAX", "Los Angeles", "USA", 33.9416, -118.4085),
            ("LGB", "Long Beach", "USA", 33.8177, -118.1516),
            ("LCK", "Columbus", "USA", 39.8138, -82.9278),
            ("LRD", "Laredo", "USA", 27.5438, -99.4616),
            ("MCI", "Kansas City", "USA", 39.2976, -94.7139),
            ("MCO", "Orlando", "USA", 28.4312, -81.3081),
            ("MDT", "Harrisburg", "USA", 40.1935, -76.7634),
            ("MEM", "Memphis", "USA", 35.0424, -89.9767),
            ("MFE", "McAllen", "USA", 26.1758, -98.2386),
            ("MHR", "Sacramento", "USA", 38.5539, -121.2973),
            ("MKE", "Milwaukee", "USA", 42.9472, -87.8966),
            ("MSP", "Minneapolis", "USA", 44.8848, -93.2223),
            ("MSY", "New Orleans", "USA", 29.9934, -90.2580),
            ("OAK", "Oakland", "USA", 37.7214, -122.2208),
            ("OKC", "Oklahoma City", "USA", 35.3931, -97.6007),
            ("OMA", "Omaha", "USA", 41.3032, -95.8941),
            ("ORD", "Chicago", "USA", 41.9742, -87.9073),
            ("ORF", "Norfolk", "USA", 36.8946, -76.2012),
            ("PBI", "West Palm Beach", "USA", 26.6832, -80.0956),
            ("PDX", "Portland", "USA", 45.5887, -122.5968),
            ("PHX", "Phoenix", "USA", 33.4352, -112.0101),
            ("PIT", "Pittsburgh", "USA", 40.4915, -80.2329),
            ("RDU", "Raleigh/Durham", "USA", 35.8801, -78.7880),
            ("RNO", "Reno", "USA", 39.4991, -119.7681),
            ("RSW", "Fort Myers", "USA", 26.5362, -81.7552),
            ("SAN", "San Diego", "USA", 32.7336, -117.1897),
            ("SAT", "San Antonio", "USA", 29.5337, -98.4698),
            ("SLC", "Salt Lake City", "USA", 40.7899, -111.9791),
            ("STL", "St. Louis", "USA", 38.7487, -90.3700),
            ("SYR", "Syracuse", "USA", 43.1112, -76.1063),
            ("PNS", "Pensacola", "USA", 30.4734, -87.1866),
            ("TPA", "Tampa", "USA", 27.9756, -82.5333),
            ("TUL", "Tulsa", "USA", 36.1984, -95.8881),
            ("TYS", "Knoxville", "USA", 35.8107, -83.9940),
            ("FWA", "Fort Wayne", "USA", 40.9785, -85.1951),
            ("PVD", "Providence", "USA", 41.7326, -71.4203),
            ("SBN", "South Bend", "USA", 41.7087, -86.3173),
            ("SBD", "San Bernardino", "USA", 34.0954, -117.2350),
            ("BGR", "Bangor", "USA", 44.8074, -68.8281),
            ("MHT", "Manchester", "USA", 42.9326, -71.4357),
            ("FAR", "Fargo", "USA", 46.9207, -96.8158),
            ("SEA", "Seattle", "USA", 47.4502, -122.3088),
            ("SFO", "San Francisco", "USA", 37.6213, -122.3790),
            ("DCA", "Washington DC", "USA", 38.8512, -77.0402),
            ("LGA", "New York", "USA", 40.7769, -73.8740),
            ("MDW", "Chicago", "USA", 41.7868, -87.7522),
            ("DAL", "Dallas", "USA", 32.8471, -96.8518),
            ("HOU", "Houston", "USA", 29.6454, -95.2789),
            ("FLL", "Fort Lauderdale", "USA", 26.0742, -80.1506),
            ("ABQ", "Albuquerque", "USA", 35.0402, -106.6094),
            ("SMF", "Sacramento", "USA", 38.6954, -121.5908),
            ("SJC", "San Jose", "USA", 37.3626, -121.9291),
            ("SNA", "Santa Ana", "USA", 33.6757, -117.8682),
            ("CMH", "Columbus", "USA", 39.9980, -82.8919),
            ("BUR", "Burbank", "USA", 34.2005, -118.3585),
            ("PSP", "Palm Springs", "USA", 33.8303, -116.5067),
            ("TUS", "Tucson", "USA", 32.1161, -110.9410),

            // Northeast regional
            ("PWM", "Portland", "USA", 43.6462, -70.3093),
            ("ROC", "Rochester", "USA", 43.1189, -77.6724),
            ("BGM", "Binghamton", "USA", 42.2087, -75.9798),
            ("HPN", "White Plains", "USA", 41.0670, -73.7076),
            ("ORH", "Worcester", "USA", 42.2673, -71.8757),
            ("ACY", "Atlantic City", "USA", 39.4576, -74.5772),
            ("PHF", "Newport News", "USA", 37.1319, -76.4930),
            ("RIC", "Richmond", "USA", 37.5052, -77.3197),
            ("CRW", "Charleston", "USA", 38.3731, -81.5932),
            ("CHO", "Charlottesville", "USA", 38.1386, -78.4529),

            // Southeast regional
            ("CHS", "Charleston", "USA", 32.8986, -80.0405),
            ("SAV", "Savannah", "USA", 32.1276, -81.2021),
            ("AGS", "Augusta", "USA", 33.3699, -81.9645),
            ("ABY", "Albany", "USA", 31.5356, -84.1944),
            ("AVL", "Asheville", "USA", 35.4362, -82.5418),
            ("ILM", "Wilmington", "USA", 34.2706, -77.9026),
            ("CHA", "Chattanooga", "USA", 35.0353, -85.2038),
            ("TRI", "Bristol/Kingsport", "USA", 36.4752, -82.4074),
            ("LEX", "Lexington", "USA", 38.0365, -84.6059),
            ("SRQ", "Sarasota", "USA", 27.3954, -82.5544),
            ("TLH", "Tallahassee", "USA", 30.3965, -84.3503),
            ("GNV", "Gainesville", "USA", 29.6900, -82.2718),
            ("MLB", "Melbourne", "USA", 28.1028, -80.6453),
            ("MGM", "Montgomery", "USA", 32.3006, -86.3940),
            ("ISO", "Kinston", "USA", 35.3314, -77.6088),

            // Midwest regional
            ("EVV", "Evansville", "USA", 38.0370, -87.5324),
            ("GRR", "Grand Rapids", "USA", 42.8808, -85.5228),
            ("DAY", "Dayton", "USA", 39.9024, -84.2194),
            ("TOL", "Toledo", "USA", 41.5868, -83.8078),
            ("FNT", "Flint", "USA", 42.9654, -83.7436),
            ("MBS", "Saginaw", "USA", 43.5329, -84.0796),
            ("AZO", "Kalamazoo", "USA", 42.2350, -85.5521),
            ("MSN", "Madison", "USA", 43.1399, -89.3375),
            ("GRB", "Green Bay", "USA", 44.4851, -88.1296),
            ("LSE", "La Crosse", "USA", 43.8793, -91.2566),
            ("CID", "Cedar Rapids", "USA", 41.8847, -91.7108),
            ("DBQ", "Dubuque", "USA", 42.4020, -90.7095),
            ("ALO", "Waterloo", "USA", 42.5571, -92.4003),
            ("MLI", "Moline", "USA", 41.4485, -90.5075),
            ("PIA", "Peoria", "USA", 40.6642, -89.6933),
            ("BMI", "Bloomington", "USA", 40.4771, -88.9159),
            ("CMI", "Champaign", "USA", 40.0392, -88.2781),
            ("SGF", "Springfield", "USA", 37.2457, -93.3886),
            ("RST", "Rochester", "USA", 43.9083, -92.5000),
            ("DLH", "Duluth", "USA", 46.8421, -92.1936),
            ("FSD", "Sioux Falls", "USA", 43.5820, -96.7419),
            ("GFK", "Grand Forks", "USA", 47.9493, -97.1761),
            ("BIS", "Bismarck", "USA", 46.7727, -100.7468),
            ("MOT", "Minot", "USA", 48.2594, -101.2803),
            ("SUX", "Sioux City", "USA", 42.4026, -96.3844),
            ("LNK", "Lincoln", "USA", 40.8510, -96.7592),
            ("COU", "Columbia", "USA", 38.8181, -92.2196),

            // Mountain West
            ("BZN", "Bozeman", "USA", 45.7775, -111.1530),
            ("GTF", "Great Falls", "USA", 47.4820, -111.3707),
            ("FCA", "Kalispell", "USA", 48.3105, -114.2560),
            ("RAP", "Rapid City", "USA", 44.0453, -103.0574),
            ("COS", "Colorado Springs", "USA", 38.8058, -104.7008),
            ("GJT", "Grand Junction", "USA", 39.1224, -108.5267),
            ("JAC", "Jackson", "USA", 43.6073, -110.7377),

            // Texas / Southwest
            ("LIT", "Little Rock", "USA", 34.7294, -92.2243),
            ("XNA", "Bentonville", "USA", 36.2819, -94.3068),
            ("FSM", "Fort Smith", "USA", 35.3366, -94.3674),
            ("SHV", "Shreveport", "USA", 32.4466, -93.8256),
            ("MLU", "Monroe", "USA", 32.5109, -92.0377),
            ("LBB", "Lubbock", "USA", 33.6636, -101.8227),
            ("MAF", "Midland", "USA", 31.9425, -102.2019),
            ("AMA", "Amarillo", "USA", 35.2194, -101.7059),
            ("CRP", "Corpus Christi", "USA", 27.7704, -97.5012),
            ("HRL", "Harlingen", "USA", 26.2285, -97.6544),
            ("BRO", "Brownsville", "USA", 25.9068, -97.4259),
            ("ACT", "Waco", "USA", 31.6113, -97.2305),

            // Alaska
            ("FAI", "Fairbanks", "USA", 64.8151, -147.8561),
            ("JNU", "Juneau", "USA", 58.3550, -134.5763),

            // Canada
            ("YYZ", "Toronto", "Canada", 43.6777, -79.6248),
            ("YVR", "Vancouver", "Canada", 49.1947, -123.1792),
            ("YYC", "Calgary", "Canada", 51.1215, -114.0076),
            ("YUL", "Montreal", "Canada", 45.4706, -73.7408),
            ("YEG", "Edmonton", "Canada", 53.3097, -113.5800),
            ("YOW", "Ottawa", "Canada", 45.3225, -75.6692),
            ("YWG", "Winnipeg", "Canada", 49.9100, -97.2399),
            ("YHZ", "Halifax", "Canada", 44.8808, -63.5086),
            ("YYT", "St. John's", "Canada", 47.6186, -52.7519),

            // Mexico
            ("MEX", "Mexico City", "Mexico", 19.4363, -99.0721),
            ("GDL", "Guadalajara", "Mexico", 20.5218, -103.3111),
            ("CUN", "Cancun", "Mexico", 21.0365, -86.8771),
            ("PVR", "Puerto Vallarta", "Mexico", 20.6801, -105.2544),
            ("SJD", "San Jose del Cabo", "Mexico", 23.1518, -109.7215),

            // Caribbean
            ("STT", "Charlotte Amalie", "US Virgin Islands", 18.3373, -64.9734),
            ("STX", "Christiansted", "US Virgin Islands", 17.7019, -64.7986),
            ("NAS", "Nassau", "Bahamas", 25.0390, -77.4662),
            ("KIN", "Kingston", "Jamaica", 17.9357, -76.7875),
            ("MBJ", "Montego Bay", "Jamaica", 18.5037, -77.9134),
            ("AUA", "Oranjestad", "Aruba", 12.5014, -70.0152),
            ("CUR", "Willemstad", "Curaçao", 12.1889, -68.9598),
            ("SXM", "Philipsburg", "Sint Maarten", 18.0410, -63.1089),
            ("BGI", "Bridgetown", "Barbados", 13.0746, -59.4925),
            ("POS", "Port of Spain", "Trinidad and Tobago", 10.5954, -61.3372),
            ("SDQ", "Santo Domingo", "Dominican Republic", 18.4297, -69.6689),
            ("PUJ", "Punta Cana", "Dominican Republic", 18.5674, -68.3634),
            ("PLS", "Providenciales", "Turks and Caicos", 21.7736, -72.2659),
            ("GCM", "George Town", "Cayman Islands", 19.2928, -81.3577),

            // Central America
            ("PTY", "Panama City", "Panama", 9.0714, -79.3835),
            ("SJO", "San Jose", "Costa Rica", 9.9939, -84.2088),
            ("LIR", "Liberia", "Costa Rica", 10.5933, -85.5444),
            ("GUA", "Guatemala City", "Guatemala", 14.5833, -90.5275),
            ("SAL", "San Salvador", "El Salvador", 13.4409, -89.0557),
            ("SAP", "San Pedro Sula", "Honduras", 15.4526, -87.9236),
            ("TGU", "Tegucigalpa", "Honduras", 14.0609, -87.2172),
            ("MGA", "Managua", "Nicaragua", 12.1415, -86.1682),
            ("BZE", "Belize City", "Belize", 17.5391, -88.3082),

            // South America
            ("BOG", "Bogota", "Colombia", 4.7016, -74.1469),
            ("GRU", "Sao Paulo", "Brazil", -23.4356, -46.4731),
            ("GIG", "Rio de Janeiro", "Brazil", -22.8099, -43.2506),
            ("BSB", "Brasilia", "Brazil", -15.8711, -47.9186),
            ("EZE", "Buenos Aires", "Argentina", -34.8222, -58.5358),
            ("SCL", "Santiago", "Chile", -33.3930, -70.7858),
            ("LIM", "Lima", "Peru", -12.0219, -77.1143),
            ("UIO", "Quito", "Ecuador", -0.1292, -78.3575),
            ("GYE", "Guayaquil", "Ecuador", -2.1574, -79.8837),
            ("CCS", "Caracas", "Venezuela", 10.6012, -66.9912),
            ("MVD", "Montevideo", "Uruguay", -34.8384, -56.0308),

            // Asia (common UPS destinations)
            ("ICN", "Seoul", "South Korea", 37.4602, 126.4407),
            ("NRT", "Tokyo", "Japan", 35.7647, 140.3864),
            ("KIX", "Osaka", "Japan", 34.4347, 135.2441),
            ("TPE", "Taipei", "Taiwan", 25.0797, 121.2342),
            ("SIN", "Singapore", "Singapore", 1.3644, 103.9915),
            ("BKK", "Bangkok", "Thailand", 13.6900, 100.7501),
            ("DEL", "New Delhi", "India", 28.5562, 77.1000),
            ("BOM", "Mumbai", "India", 19.0896, 72.8656),
            ("DXB", "Dubai", "UAE", 25.2532, 55.3657),
            ("DWC", "Dubai", "UAE", 24.8960, 55.1614),
            ("DOH", "Doha", "Qatar", 25.2731, 51.6081),
            ("PEK", "Beijing", "China", 40.0799, 116.6031),
            ("CAN", "Guangzhou", "China", 23.3924, 113.2988),
            ("CGO", "Zhengzhou", "China", 34.5197, 113.8409),
            ("HND", "Tokyo", "Japan", 35.5494, 139.7798),
            ("KUL", "Kuala Lumpur", "Malaysia", 2.7456, 101.7099),
            ("CRK", "Angeles City", "Philippines", 15.1860, 120.5603),
            ("MNL", "Manila", "Philippines", 14.5086, 121.0198),
            ("CGK", "Jakarta", "Indonesia", -6.1256, 106.6559),
            ("HAN", "Hanoi", "Vietnam", 21.2212, 105.8070),
            ("BLR", "Bangalore", "India", 13.1986, 77.7066),
            ("TLV", "Tel Aviv", "Israel", 32.0114, 34.8867),
            ("PEN", "Penang", "Malaysia", 5.2972, 100.2769),
            ("SGN", "Ho Chi Minh City", "Vietnam", 10.8188, 106.6520),
            ("DAC", "Dhaka", "Bangladesh", 23.8432, 90.3977),
            ("CMB", "Colombo", "Sri Lanka", 7.1808, 79.8843),
            ("BAH", "Bahrain", "Bahrain", 26.2708, 50.6336),
            ("AMM", "Amman", "Jordan", 31.7226, 35.9932),
            ("NGO", "Nagoya", "Japan", 34.8584, 136.8125),
            ("TAO", "Qingdao", "China", 36.2661, 120.3744),

            // Europe
            ("LHR", "London", "UK", 51.4700, -0.4543),
            ("CDG", "Paris", "France", 49.0097, 2.5479),
            ("FRA", "Frankfurt", "Germany", 50.0379, 8.5622),
            ("AMS", "Amsterdam", "Netherlands", 52.3105, 4.7683),
            ("BRU", "Brussels", "Belgium", 50.9014, 4.4844),
            ("MAD", "Madrid", "Spain", 40.4983, -3.5676),
            ("FCO", "Rome", "Italy", 41.8003, 12.2389),
            ("MXP", "Milan", "Italy", 45.6306, 8.7281),
            ("STN", "London", "UK", 51.8850, 0.2350),
            ("BCN", "Barcelona", "Spain", 41.2971, 2.0785),
            ("VLC", "Valencia", "Spain", 39.4893, -0.4816),
            ("VCE", "Venice", "Italy", 45.5053, 12.3519),
            ("MUC", "Munich", "Germany", 48.3537, 11.7750),
            ("ZRH", "Zurich", "Switzerland", 47.4647, 8.5492),
            ("VIE", "Vienna", "Austria", 48.1103, 16.5697),
            ("CPH", "Copenhagen", "Denmark", 55.6180, 12.6508),
            ("ARN", "Stockholm", "Sweden", 59.6519, 17.9186),
            ("OSL", "Oslo", "Norway", 60.1939, 11.1004),
            ("HEL", "Helsinki", "Finland", 60.3172, 24.9633),
            ("DUB", "Dublin", "Ireland", 53.4213, -6.2701),
            ("WAW", "Warsaw", "Poland", 52.1657, 20.9671),
            ("PRG", "Prague", "Czech Republic", 50.1008, 14.2600),
            ("BUD", "Budapest", "Hungary", 47.4369, 19.2556),
            ("IST", "Istanbul", "Turkey", 41.2753, 28.7519),
            ("ATH", "Athens", "Greece", 37.9364, 23.9445),
            ("LIS", "Lisbon", "Portugal", 38.7813, -9.1359),
        ]

        var dict = [String: AirportData]()
        dict.reserveCapacity(entries.count)
        for (iata, city, country, lat, lon) in entries {
            dict[iata] = AirportData(iata: iata, city: city, country: country, latitude: lat, longitude: lon)
        }
        return dict
    }
}

// MARK: - Country Flag Support

extension AirportData {
    /// Returns flag emoji for non-USA countries, nil for USA
    var countryFlagEmoji: String? {
        guard country != "USA" else { return nil }
        return Self.countryFlags[country]
    }

    var isInternational: Bool {
        country != "USA"
    }

    private static let countryFlags: [String: String] = [
        "Canada": "\u{1F1E8}\u{1F1E6}",
        "Mexico": "\u{1F1F2}\u{1F1FD}",
        "Germany": "\u{1F1E9}\u{1F1EA}",
        "China": "\u{1F1E8}\u{1F1F3}",
        "UK": "\u{1F1EC}\u{1F1E7}",
        "Puerto Rico": "\u{1F1F5}\u{1F1F7}",
        "South Korea": "\u{1F1F0}\u{1F1F7}",
        "Japan": "\u{1F1EF}\u{1F1F5}",
        "Taiwan": "\u{1F1F9}\u{1F1FC}",
        "Singapore": "\u{1F1F8}\u{1F1EC}",
        "Thailand": "\u{1F1F9}\u{1F1ED}",
        "India": "\u{1F1EE}\u{1F1F3}",
        "UAE": "\u{1F1E6}\u{1F1EA}",
        "France": "\u{1F1EB}\u{1F1F7}",
        "Netherlands": "\u{1F1F3}\u{1F1F1}",
        "Belgium": "\u{1F1E7}\u{1F1EA}",
        "Spain": "\u{1F1EA}\u{1F1F8}",
        "Italy": "\u{1F1EE}\u{1F1F9}",
        "US Virgin Islands": "\u{1F1FB}\u{1F1EE}",
        "Bahamas": "\u{1F1E7}\u{1F1F8}",
        "Jamaica": "\u{1F1EF}\u{1F1F2}",
        "Aruba": "\u{1F1E6}\u{1F1FC}",
        "Curaçao": "\u{1F1E8}\u{1F1FC}",
        "Sint Maarten": "\u{1F1F8}\u{1F1FD}",
        "Barbados": "\u{1F1E7}\u{1F1E7}",
        "Trinidad and Tobago": "\u{1F1F9}\u{1F1F9}",
        "Dominican Republic": "\u{1F1E9}\u{1F1F4}",
        "Turks and Caicos": "\u{1F1F9}\u{1F1E8}",
        "Cayman Islands": "\u{1F1F0}\u{1F1FE}",
        "Panama": "\u{1F1F5}\u{1F1E6}",
        "Costa Rica": "\u{1F1E8}\u{1F1F7}",
        "Guatemala": "\u{1F1EC}\u{1F1F9}",
        "El Salvador": "\u{1F1F8}\u{1F1FB}",
        "Honduras": "\u{1F1ED}\u{1F1F3}",
        "Nicaragua": "\u{1F1F3}\u{1F1EE}",
        "Belize": "\u{1F1E7}\u{1F1FF}",
        "Colombia": "\u{1F1E8}\u{1F1F4}",
        "Brazil": "\u{1F1E7}\u{1F1F7}",
        "Argentina": "\u{1F1E6}\u{1F1F7}",
        "Chile": "\u{1F1E8}\u{1F1F1}",
        "Peru": "\u{1F1F5}\u{1F1EA}",
        "Ecuador": "\u{1F1EA}\u{1F1E8}",
        "Venezuela": "\u{1F1FB}\u{1F1EA}",
        "Uruguay": "\u{1F1FA}\u{1F1FE}",
        "Malaysia": "\u{1F1F2}\u{1F1FE}",
        "Philippines": "\u{1F1F5}\u{1F1ED}",
        "Indonesia": "\u{1F1EE}\u{1F1E9}",
        "Vietnam": "\u{1F1FB}\u{1F1F3}",
        "Qatar": "\u{1F1F6}\u{1F1E6}",
        "Israel": "\u{1F1EE}\u{1F1F1}",
        "Switzerland": "\u{1F1E8}\u{1F1ED}",
        "Austria": "\u{1F1E6}\u{1F1F9}",
        "Denmark": "\u{1F1E9}\u{1F1F0}",
        "Sweden": "\u{1F1F8}\u{1F1EA}",
        "Norway": "\u{1F1F3}\u{1F1F4}",
        "Finland": "\u{1F1EB}\u{1F1EE}",
        "Ireland": "\u{1F1EE}\u{1F1EA}",
        "Poland": "\u{1F1F5}\u{1F1F1}",
        "Czech Republic": "\u{1F1E8}\u{1F1FF}",
        "Hungary": "\u{1F1ED}\u{1F1FA}",
        "Turkey": "\u{1F1F9}\u{1F1F7}",
        "Greece": "\u{1F1EC}\u{1F1F7}",
        "Portugal": "\u{1F1F5}\u{1F1F9}",
        "Australia": "\u{1F1E6}\u{1F1FA}",
        "New Zealand": "\u{1F1F3}\u{1F1FF}",
        "South Africa": "\u{1F1FF}\u{1F1E6}",
        "Kenya": "\u{1F1F0}\u{1F1EA}",
        "Ethiopia": "\u{1F1EA}\u{1F1F9}",
        "Nigeria": "\u{1F1F3}\u{1F1EC}",
        "Egypt": "\u{1F1EA}\u{1F1EC}",
        "Bangladesh": "\u{1F1E7}\u{1F1E9}",
        "Sri Lanka": "\u{1F1F1}\u{1F1F0}",
        "Bahrain": "\u{1F1E7}\u{1F1ED}",
        "Jordan": "\u{1F1EF}\u{1F1F4}",
    ]
}
