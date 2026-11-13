//
//  AirportMark.swift
//  CrewLuve
//
//  An airport on the trip map (moving map spec §5.1).
//

import CoreLocation

nonisolated struct AirportMark: Identifiable {
    let code: String
    let city: String?
    let coordinate: CLLocationCoordinate2D
    /// The airport's time zone when the legs say, for "9:14 PM there".
    let timeZone: TimeZone?

    var id: String { code }

    /// The city when the legs name it, else the code.
    var name: String { city ?? code }
}
