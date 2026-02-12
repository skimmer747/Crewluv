//
//  TripStateResolver.swift
//  CrewLuv
//
//  Pure stateless resolver: [TripLeg] + Date → ResolvedPilotState
//

import Foundation

struct ResolvedPilotState {
    let displayStatus: String
    let isHome: Bool
    let isInFlight: Bool
    let isOnDuty: Bool

    let currentAirport: String?
    let currentCity: String?
    let currentTimezone: String?

    let currentFlightNumber: String?
    let currentFlightDeparture: String?
    let currentFlightArrival: String?
    let currentFlightDepartureTime: Date?
    let currentFlightArrivalTime: Date?
    let currentFlightArrivalTimezone: String?

    let homeArrivalTime: Date?
    let nextDepartureTime: Date?
    let nextFlightNumber: String?
    let nextFlightDestination: String?

    let tripDayNumber: Int?
    let tripTotalDays: Int?
    let upcomingCities: [String]

    let timeUntilNextTransition: TimeInterval?
}

enum TripStateResolver {

    static func resolve(legs: [TripLeg], at now: Date) -> ResolvedPilotState {
        let sorted = legs.sorted { $0.startTime < $1.startTime }

        // Find the current leg: startTime <= now < endTime
        let currentLeg = sorted.first { $0.startTime <= now && now < $0.endTime }

        // Future legs: startTime >= now, excluding the current leg by id
        let currentLegId = currentLeg?.id
        let futureLegs = sorted.filter { $0.startTime >= now && $0.id != currentLegId }

        // If no current leg, we're home (before trip, after trip, or in a gap)
        guard let leg = currentLeg else {
            return homeState(
                nextFlightLeg: futureLegs.first { $0.type == .flight },
                now: now
            )
        }

        let displayStatus = statusString(for: leg.type)
        let isHome = leg.type == .home
        let isInFlight = leg.type == .flight

        // Home arrival: end time of last non-home leg in the current trip segment
        // Find the boundary: the first .home leg after the current leg marks the trip end
        let homeArrivalTime: Date? = {
            guard !isHome else { return nil }
            guard let currentIndex = sorted.firstIndex(where: { $0.id == leg.id }) else { return nil }
            // Find where this trip segment ends (next .home leg or end of array)
            let segmentEnd = sorted[currentIndex...].firstIndex { $0.type == .home } ?? sorted.endIndex
            // Last non-home leg within this segment
            return sorted[currentIndex..<segmentEnd].last { $0.type != .home }?.endTime
        }()

        // Next departure: first future flight leg's start time
        let nextFlightLeg = futureLegs.first { $0.type == .flight }
        let nextDepartureTime = nextFlightLeg?.startTime

        // Upcoming cities from future legs (deduplicated, max 5)
        let upcomingCities = deriveUpcomingCities(from: futureLegs)

        // Time until this leg ends (next transition point)
        let timeUntilNextTransition = leg.endTime.timeIntervalSince(now)

        // Prefer our own airport lookup over leg data (Duty's lookup has gaps)
        let resolvedTimezone: String? = isInFlight
            ? (airportTimezone(leg.departureAirport) ?? leg.timezoneIdentifier)
            : (airportTimezone(leg.airportCode) ?? leg.timezoneIdentifier)
        let arrivalTimezone: String? = isInFlight
            ? (airportTimezone(leg.arrivalAirport) ?? futureLegs.first?.timezoneIdentifier)
            : nil

        return ResolvedPilotState(
            displayStatus: displayStatus,
            isHome: isHome,
            isInFlight: isInFlight,
            isOnDuty: !isHome,
            currentAirport: isInFlight ? leg.departureAirport : leg.airportCode,
            currentCity: isInFlight ? nil : leg.city,
            currentTimezone: resolvedTimezone,
            currentFlightNumber: isInFlight ? leg.flightNumber : nil,
            currentFlightDeparture: isInFlight ? leg.departureAirport : nil,
            currentFlightArrival: isInFlight ? leg.arrivalAirport : nil,
            currentFlightDepartureTime: isInFlight ? leg.startTime : nil,
            currentFlightArrivalTime: isInFlight ? leg.endTime : nil,
            currentFlightArrivalTimezone: arrivalTimezone,
            homeArrivalTime: homeArrivalTime,
            nextDepartureTime: nextDepartureTime,
            nextFlightNumber: nextFlightLeg?.flightNumber,
            nextFlightDestination: nextFlightLeg?.arrivalAirport,
            tripDayNumber: leg.tripDayNumber,
            tripTotalDays: leg.tripTotalDays,
            upcomingCities: upcomingCities,
            timeUntilNextTransition: timeUntilNextTransition > 0 ? timeUntilNextTransition : nil
        )
    }

    // MARK: - Private

    private static func homeState(nextFlightLeg: TripLeg?, now: Date) -> ResolvedPilotState {
        ResolvedPilotState(
            displayStatus: "Home",
            isHome: true,
            isInFlight: false,
            isOnDuty: false,
            currentAirport: nil,
            currentCity: nil,
            currentTimezone: nil,
            currentFlightNumber: nil,
            currentFlightDeparture: nil,
            currentFlightArrival: nil,
            currentFlightDepartureTime: nil,
            currentFlightArrivalTime: nil,
            currentFlightArrivalTimezone: nil,
            homeArrivalTime: nil,
            nextDepartureTime: nextFlightLeg?.startTime,
            nextFlightNumber: nextFlightLeg?.flightNumber,
            nextFlightDestination: nextFlightLeg?.arrivalAirport,
            tripDayNumber: nil,
            tripTotalDays: nil,
            upcomingCities: [],
            timeUntilNextTransition: nextFlightLeg.flatMap { leg in
                let interval = leg.startTime.timeIntervalSince(now)
                return interval > 0 ? interval : nil
            }
        )
    }

    private static func statusString(for type: TripLeg.LegType) -> String {
        switch type {
        case .flight:     return "In Flight"
        case .turn:       return "Turn"
        case .layover:    return "Layover"
        case .home:       return "Home"
        case .reserve:    return "Reserve"
        case .hotStandby: return "Hot Standby"
        case .event:      return "Event"
        case .unknown:    return "On Duty"
        }
    }

    // Mirrors Duty's TripParser.getTimeZoneForAirport — keep in sync
    private static let airportTimeZones: [String: String] = [
        // Eastern Time (EST/EDT)
        "ATL": "America/New_York",
        "BOS": "America/New_York",
        "BWI": "America/New_York",
        "CHS": "America/New_York",
        "CLT": "America/New_York",
        "CMH": "America/New_York",
        "CVG": "America/New_York",
        "DCA": "America/New_York",
        "DTW": "America/New_York",
        "EWR": "America/New_York",
        "FLL": "America/New_York",
        "FWA": "America/New_York",
        "IAD": "America/New_York",
        "IND": "America/New_York",
        "JFK": "America/New_York",
        "LGA": "America/New_York",
        "MCO": "America/New_York",
        "MIA": "America/New_York",
        "ORF": "America/New_York",
        "PBI": "America/New_York",
        "PHL": "America/New_York",
        "PIT": "America/New_York",
        "PVD": "America/New_York",
        "RDU": "America/New_York",
        "RIC": "America/New_York",
        "ROC": "America/New_York",
        "RSW": "America/New_York",
        "SBN": "America/New_York",
        "SDF": "America/New_York",
        "GATC": "America/New_York",
        "SRQ": "America/New_York",
        "SYR": "America/New_York",
        "TPA": "America/New_York",
        "BDL": "America/New_York",
        "BUF": "America/New_York",
        "CAE": "America/New_York",
        "CLE": "America/New_York",
        "DAY": "America/New_York",
        "GRR": "America/New_York",
        "GSO": "America/New_York",
        "GSP": "America/New_York",
        "JAX": "America/New_York",
        "LEX": "America/New_York",
        "MHT": "America/New_York",
        "ORH": "America/New_York",
        "PWM": "America/New_York",
        "SAV": "America/New_York",
        "TYS": "America/New_York",
        "ACY": "America/New_York",
        "AGS": "America/New_York",
        "ABY": "America/New_York",
        "ALB": "America/New_York",
        "AVL": "America/New_York",
        "AZO": "America/New_York",
        "BGR": "America/New_York",
        "BGM": "America/New_York",
        "CHA": "America/New_York",
        "CHO": "America/New_York",
        "CRW": "America/New_York",
        "FNT": "America/New_York",
        "GNV": "America/New_York",
        "HPN": "America/New_York",
        "ILM": "America/New_York",
        "ISO": "America/New_York",
        "LAN": "America/New_York",
        "MBS": "America/New_York",
        "MDT": "America/New_York",
        "MLB": "America/New_York",
        "PHF": "America/New_York",
        "TLH": "America/New_York",
        "TOL": "America/New_York",
        "TRI": "America/New_York",

        // Central Time (CST/CDT)
        "AUS": "America/Chicago",
        "BNA": "America/Chicago",
        "DAL": "America/Chicago",
        "DFW": "America/Chicago",
        "DSM": "America/Chicago",
        "GYY": "America/Chicago",
        "HOU": "America/Chicago",
        "IAH": "America/Chicago",
        "JAN": "America/Chicago",
        "MCI": "America/Chicago",
        "MDW": "America/Chicago",
        "MEM": "America/Chicago",
        "MKE": "America/Chicago",
        "MSP": "America/Chicago",
        "MSY": "America/Chicago",
        "OKC": "America/Chicago",
        "OMA": "America/Chicago",
        "ORD": "America/Chicago",
        "SAT": "America/Chicago",
        "STL": "America/Chicago",
        "TUL": "America/Chicago",
        "BHM": "America/Chicago",
        "ICT": "America/Chicago",
        "LIT": "America/Chicago",
        "MLI": "America/Chicago",
        "XNA": "America/Chicago",
        "ACT": "America/Chicago",
        "ALO": "America/Chicago",
        "AMA": "America/Chicago",
        "BIS": "America/Chicago",
        "BMI": "America/Chicago",
        "BRO": "America/Chicago",
        "CID": "America/Chicago",
        "CMI": "America/Chicago",
        "COU": "America/Chicago",
        "CRP": "America/Chicago",
        "DBQ": "America/Chicago",
        "DLH": "America/Chicago",
        "EVV": "America/Chicago",
        "FAR": "America/Chicago",
        "FSD": "America/Chicago",
        "FSM": "America/Chicago",
        "GFK": "America/Chicago",
        "GRB": "America/Chicago",
        "HRL": "America/Chicago",
        "HSV": "America/Chicago",
        "LBB": "America/Chicago",
        "LNK": "America/Chicago",
        "LRD": "America/Chicago",
        "LSE": "America/Chicago",
        "MAF": "America/Chicago",
        "MGM": "America/Chicago",
        "MLU": "America/Chicago",
        "PNS": "America/Chicago",
        "MOT": "America/Chicago",
        "MSN": "America/Chicago",
        "PIA": "America/Chicago",
        "RFD": "America/Chicago",
        "RST": "America/Chicago",
        "SGF": "America/Chicago",
        "SHV": "America/Chicago",
        "SUX": "America/Chicago",

        // Mountain Time (MST/MDT)
        "ABQ": "America/Denver",
        "BIL": "America/Denver",
        "BOI": "America/Denver",
        "BZN": "America/Denver",
        "COS": "America/Denver",
        "DEN": "America/Denver",
        "ELP": "America/Denver",
        "GJT": "America/Denver",
        "JAC": "America/Denver",
        "SLC": "America/Denver",
        "FCA": "America/Denver",
        "GTF": "America/Denver",
        "RAP": "America/Denver",

        // Arizona (no DST)
        "PHX": "America/Phoenix",
        "TUS": "America/Phoenix",

        // Pacific Time (PST/PDT)
        "BUR": "America/Los_Angeles",
        "FAT": "America/Los_Angeles",
        "LAS": "America/Los_Angeles",
        "LAX": "America/Los_Angeles",
        "LGB": "America/Los_Angeles",
        "OAK": "America/Los_Angeles",
        "ONT": "America/Los_Angeles",
        "PDX": "America/Los_Angeles",
        "BFI": "America/Los_Angeles",
        "PSP": "America/Los_Angeles",
        "RNO": "America/Los_Angeles",
        "SAN": "America/Los_Angeles",
        "SBD": "America/Los_Angeles",
        "SNA": "America/Los_Angeles",
        "SEA": "America/Los_Angeles",
        "SFO": "America/Los_Angeles",
        "SJC": "America/Los_Angeles",
        "SMF": "America/Los_Angeles",
        "MHR": "America/Los_Angeles",
        "GEG": "America/Los_Angeles",

        // Alaska Time
        "ANC": "America/Anchorage",
        "FAI": "America/Anchorage",
        "JNU": "America/Anchorage",

        // Hawaii Time (no DST)
        "HNL": "Pacific/Honolulu",
        "OGG": "Pacific/Honolulu",
        "KOA": "Pacific/Honolulu",
        "LIH": "Pacific/Honolulu",

        // US Territories
        "SJU": "America/Puerto_Rico",
        "STT": "America/St_Thomas",
        "STX": "America/St_Thomas",
        "GUM": "Pacific/Guam",
        "PPG": "Pacific/Pago_Pago",

        // Canada
        "YEG": "America/Edmonton",
        "YHM": "America/Toronto",
        "YHZ": "America/Halifax",
        "YMX": "America/Montreal",
        "YOW": "America/Toronto",
        "YUL": "America/Toronto",
        "YVR": "America/Vancouver",
        "YWG": "America/Winnipeg",
        "YYC": "America/Denver",
        "YYZ": "America/Toronto",
        "YYT": "America/St_Johns",

        // Mexico
        "CUN": "America/Cancun",
        "GDL": "America/Mexico_City",
        "MEX": "America/Mexico_City",
        "NLU": "America/Mexico_City",
        "PVR": "America/Mexico_City",
        "SJD": "America/Mazatlan",

        // Caribbean
        "AUA": "America/Aruba",
        "BGI": "America/Barbados",
        "CUR": "America/Curacao",
        "GCM": "America/Cayman",
        "KIN": "America/Jamaica",
        "MBJ": "America/Jamaica",
        "NAS": "America/Nassau",
        "PLS": "America/Grand_Turk",
        "POS": "America/Port_of_Spain",
        "PUJ": "America/Santo_Domingo",
        "SDQ": "America/Santo_Domingo",
        "SXM": "America/Lower_Princes",

        // Central America
        "BZE": "America/Belize",
        "GUA": "America/Guatemala",
        "LIR": "America/Costa_Rica",
        "MGA": "America/Managua",
        "PTY": "America/Panama",
        "SAL": "America/El_Salvador",
        "SAP": "America/Tegucigalpa",
        "SJO": "America/Costa_Rica",
        "TGU": "America/Tegucigalpa",

        // South America
        "BOG": "America/Bogota",
        "BSB": "America/Sao_Paulo",
        "CCS": "America/Caracas",
        "EZE": "America/Argentina/Buenos_Aires",
        "GIG": "America/Sao_Paulo",
        "GRU": "America/Sao_Paulo",
        "GYE": "America/Guayaquil",
        "LIM": "America/Lima",
        "MVD": "America/Montevideo",
        "SCL": "America/Santiago",
        "UIO": "America/Guayaquil",

        // Europe
        "AMS": "Europe/Amsterdam",
        "BCN": "Europe/Madrid",
        "BRU": "Europe/Brussels",
        "CDG": "Europe/Paris",
        "CPH": "Europe/Copenhagen",
        "CGN": "Europe/Berlin",
        "LGG": "Europe/Brussels",
        "PRG": "Europe/Prague",
        "OSL": "Europe/Oslo",
        "ARN": "Europe/Stockholm",
        "HEL": "Europe/Helsinki",
        "ATH": "Europe/Athens",
        "IST": "Europe/Istanbul",
        "SAW": "Europe/Istanbul",
        "BSL": "Europe/Zurich",
        "BGY": "Europe/Rome",
        "BLL": "Europe/Copenhagen",
        "KRK": "Europe/Warsaw",
        "GDN": "Europe/Warsaw",
        "WRO": "Europe/Warsaw",
        "RIX": "Europe/Riga",
        "VNO": "Europe/Vilnius",
        "TLL": "Europe/Tallinn",
        "DUB": "Europe/Dublin",
        "DUS": "Europe/Berlin",
        "EMA": "Europe/London",
        "FCO": "Europe/Rome",
        "FRA": "Europe/Berlin",
        "GVA": "Europe/Zurich",
        "LGW": "Europe/London",
        "LHR": "Europe/London",
        "STN": "Europe/London",
        "MAD": "Europe/Madrid",
        "MAN": "Europe/London",
        "MUC": "Europe/Berlin",
        "MXP": "Europe/Rome",
        "VCE": "Europe/Rome",
        "ORY": "Europe/Paris",
        "SVO": "Europe/Moscow",
        "VIE": "Europe/Vienna",
        "WAW": "Europe/Warsaw",
        "ZRH": "Europe/Zurich",

        // Asia
        "BKK": "Asia/Bangkok",
        "CAN": "Asia/Shanghai",
        "CGK": "Asia/Jakarta",
        "DEL": "Asia/Kolkata",
        "DXB": "Asia/Dubai",
        "HKG": "Asia/Hong_Kong",
        "ICN": "Asia/Seoul",
        "KIX": "Asia/Tokyo",
        "HND": "Asia/Tokyo",
        "KUL": "Asia/Kuala_Lumpur",
        "MNL": "Asia/Manila",
        "NRT": "Asia/Tokyo",
        "PEK": "Asia/Shanghai",
        "PNH": "Asia/Phnom_Penh",
        "PVG": "Asia/Shanghai",
        "SIN": "Asia/Singapore",
        "TPE": "Asia/Taipei",
        "SZX": "Asia/Shanghai",
        "XMN": "Asia/Shanghai",
        "CSX": "Asia/Shanghai",
        "WUH": "Asia/Shanghai",
        "ZGZJ": "Asia/Shanghai",

        // Oceania
        "AKL": "Pacific/Auckland",
        "BNE": "Australia/Brisbane",
        "MEL": "Australia/Melbourne",
        "PER": "Australia/Perth",
        "SYD": "Australia/Sydney",

        // Africa
        "JNB": "Africa/Johannesburg",
        "CAI": "Africa/Cairo",
        "CPT": "Africa/Johannesburg",
        "NBO": "Africa/Nairobi",
        "ADD": "Africa/Addis_Ababa",
        "LOS": "Africa/Lagos",
        "ACC": "Africa/Accra",
        "CMN": "Africa/Casablanca",
        "RBA": "Africa/Casablanca",
        "ALG": "Africa/Algiers",

        // Middle East
        "TLV": "Asia/Jerusalem",
        "AMM": "Asia/Amman",
        "DOH": "Asia/Qatar",
        "AUH": "Asia/Dubai",
        "SHJ": "Asia/Dubai",
        "KWI": "Asia/Kuwait",
        "JED": "Asia/Riyadh",
        "RUH": "Asia/Riyadh",
        "BAH": "Asia/Bahrain",
        "MCT": "Asia/Muscat",

        // China Special Cases
        "ACEN": "Asia/Shanghai",
    ]

    private static func airportTimezone(_ airport: String?) -> String? {
        guard let airport else { return nil }
        return airportTimeZones[airport.uppercased()]
    }

    private static func deriveUpcomingCities(from futureLegs: [TripLeg]) -> [String] {
        var seen = Set<String>()
        var cities: [String] = []
        for leg in futureLegs {
            // Use arrivalCity for flights, city for ground legs
            let city = leg.type == .flight ? leg.arrivalCity : leg.city
            guard let c = city, !c.isEmpty, !seen.contains(c) else { continue }
            seen.insert(c)
            cities.append(c)
            if cities.count >= 5 { break }
        }
        return cities
    }
}
