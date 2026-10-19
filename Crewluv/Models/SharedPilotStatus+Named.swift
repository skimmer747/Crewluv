//
//  SharedPilotStatus+Named.swift
//  CrewLuve
//
//  The status under the name this partner calls the pilot
//

import Foundation

extension SharedPilotStatus {
    /// The same status with the pilot called `name`, the nickname the pilot set for this partner,
    /// as the title and the cards show it.
    func named(_ name: String) -> SharedPilotStatus {
        SharedPilotStatus(
            pilotId: pilotId,
            pilotFirstName: name,
            homeAirportCode: homeAirportCode,
            baseAirportCode: baseAirportCode,
            homeTimezone: homeTimezone,
            displayStatus: displayStatus,
            isSleeping: isSleeping,
            isHome: isHome,
            isInFlight: isInFlight,
            isOnDuty: isOnDuty,
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
            upcomingCities: upcomingCities,
            tripLegsJSON: tripLegsJSON,
            quickStatus: quickStatus,
            quickStatusIcon: quickStatusIcon,
            quickStatusExpiry: quickStatusExpiry,
            flightDelayMinutes: flightDelayMinutes,
            displayNameByPartnerJSON: displayNameByPartnerJSON,
            lastUpdated: lastUpdated,
            appVersion: appVersion
        )
    }
}
