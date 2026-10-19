//
//  CloudSummary.swift
//  CrewLuve
//
//  The pilot's summary as Crewlu Cloud gives it to this partner, and the status
//  the screens and alerts make of it
//

import Foundation

/// The pilot's summary as Crewlu Cloud's partner door gives it to this partner: partner_view's
/// `status`, which is CrewLu's `SharedPilotStatus` with only this partner's own entries left in it.
/// Its shape is CrewLu's `supabase/partner-status/schema.json`.
///
/// Decoding is as forgiving as the iCloud record's: only the pilot's id and first name,
/// `lastUpdated` and `appVersion` must be there. Anything else missing reads as nothing, the way
/// the door leaves out a quick status meant for someone else, and fields this version doesn't
/// know are ignored.
struct CloudSummary: Decodable, Sendable {

    // MARK: - Quick Status

    /// A quick status: this partner's own, or the one for everyone.
    struct QuickStatus: Decodable, Equatable, Sendable {
        let status: String
        let icon: String?
        /// When it stops showing. Nil means it has no limit.
        let expiry: Date?
    }

    // MARK: - Fields, Named as CrewLu Names Them

    let pilotId: String
    let pilotFirstName: String
    let homeAirportCode: String?
    let baseAirportCode: String?
    let homeTimezone: String?
    let displayStatus: String?
    let isSleeping: Bool?
    let isHome: Bool?
    let isInFlight: Bool?
    let isOnDuty: Bool?
    let currentAirport: String?
    let currentCity: String?
    let currentTimezone: String?
    let localTimeAtPilot: String?
    let currentLatitude: Double?
    let currentLongitude: Double?
    let currentFlightNumber: String?
    let currentFlightDeparture: String?
    let currentFlightArrival: String?
    let currentFlightDepartureTime: Date?
    let currentFlightArrivalTime: Date?
    let currentFlightArrivalTimezone: String?
    let homeArrivalTime: Date?
    let homeArrivalLabel: String?
    let homeArrivalCity: String?
    let nextDepartureTime: Date?
    let nextFlightNumber: String?
    let nextFlightDestination: String?
    let nextDepartureLabel: String?
    let lastTripEndDate: Date?
    let lastTripDurationDays: Int?
    let currentTripId: String?
    let tripDayNumber: Int?
    let tripTotalDays: Int?
    let upcomingCities: [String]?
    let tripLegs: [TripLeg]?
    let quickStatus: String?
    let quickStatusIcon: String?
    let quickStatusExpiry: Date?
    /// Who the top-level quick status is for, or nil for everyone. The door leaves the status in
    /// only when it's for everyone or names this partner.
    let quickStatusTargets: [String]?
    /// This partner's own quick status, under their id in lower case.
    let quickStatusByPartner: [String: QuickStatus]?
    /// The name the pilot set for this partner, under the same id.
    let displayNameByPartner: [String: String]?
    let flightDelayMinutes: Int?
    let lastUpdated: Date
    let appVersion: String

    /// Reads dates as CrewLu writes them: seconds since 1970.
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}

// MARK: - The Status the Screens Use

extension CloudSummary {

    /// The status the screens and alerts use, for this partner at `now`. The legs become iCloud's
    /// blob, so the trip logic reads them as before, and the quick status is the one this
    /// partner sees at `now`.
    func pilotStatus(partnerID: String, at now: Date) -> SharedPilotStatus {
        let shown = quickStatus(for: partnerID, at: now)
        return SharedPilotStatus(
            pilotId: pilotId,
            pilotFirstName: pilotFirstName,
            homeAirportCode: homeAirportCode,
            baseAirportCode: baseAirportCode,
            homeTimezone: homeTimezone,
            displayStatus: PilotDisplayStatus(rawDisplayString: displayStatus ?? "Home"),
            isSleeping: isSleeping ?? false,
            isHome: isHome ?? false,
            isInFlight: isInFlight ?? false,
            isOnDuty: isOnDuty ?? false,
            currentAirport: currentAirport,
            currentCity: currentCity,
            currentTimezone: currentTimezone,
            localTimeAtPilot: localTimeAtPilot,
            currentLatitude: currentLatitude,
            currentLongitude: currentLongitude,
            currentFlightNumber: currentFlightNumber,
            currentFlightDeparture: currentFlightDeparture,
            currentFlightArrival: currentFlightArrival,
            currentFlightDepartureTime: currentFlightDepartureTime,
            currentFlightArrivalTime: currentFlightArrivalTime,
            currentFlightArrivalTimezone: currentFlightArrivalTimezone,
            homeArrivalTime: homeArrivalTime,
            homeArrivalLabel: homeArrivalLabel,
            homeArrivalCity: homeArrivalCity,
            nextDepartureTime: nextDepartureTime,
            nextFlightNumber: nextFlightNumber,
            nextFlightDestination: nextFlightDestination,
            nextDepartureLabel: nextDepartureLabel,
            lastTripEndDate: lastTripEndDate,
            lastTripDurationDays: lastTripDurationDays,
            currentTripId: currentTripId,
            tripDayNumber: tripDayNumber,
            tripTotalDays: tripTotalDays,
            upcomingCities: upcomingCities ?? [],
            tripLegsJSON: tripLegs.flatMap { Self.legsBlob($0) },
            quickStatus: shown?.status,
            quickStatusIcon: shown?.icon,
            quickStatusExpiry: shown?.expiry,
            flightDelayMinutes: flightDelayMinutes,
            displayNameByPartnerJSON: nil,
            lastUpdated: lastUpdated,
            appVersion: appVersion
        )
    }

    /// The name the pilot set for this partner, or nil when there's none.
    func displayName(for partnerID: String) -> String? {
        guard let name = displayNameByPartner?[partnerID.lowercased()], !name.isEmpty else { return nil }
        return name
    }

    /// The quick status this partner sees at `now`: their own while it lasts, then the one for
    /// everyone while it lasts. A status shows until its expiry, as on the screen.
    func quickStatus(for partnerID: String, at now: Date) -> QuickStatus? {
        let id = partnerID.lowercased()
        if let own = quickStatusByPartner?[id], Self.shows(own.status, until: own.expiry, at: now) {
            return own
        }
        guard let status = quickStatus,
              Self.shows(status, until: quickStatusExpiry, at: now),
              quickStatusTargets.map({ $0.contains { $0.lowercased() == id } }) ?? true
        else { return nil }
        return QuickStatus(status: status, icon: quickStatusIcon, expiry: quickStatusExpiry)
    }

    /// When the quick status this partner sees changes by itself: when the one shown now expires.
    func quickStatusChange(for partnerID: String, after now: Date) -> Date? {
        quickStatus(for: partnerID, at: now)?.expiry
    }

    private static func shows(_ status: String, until expiry: Date?, at now: Date) -> Bool {
        !status.isEmpty && (expiry.map { $0 > now } ?? true)
    }

    /// The legs as iCloud's `tripLegsJSON` carries them. Sorted keys give the same legs the same
    /// bytes on every run, which the alerts compare.
    private static func legsBlob(_ legs: [TripLeg]) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = .sortedKeys
        return try? encoder.encode(legs)
    }
}
