//
//  FlightRouteMapView.swift
//  CrewLuve
//
//  Custom-drawn flight route visualization ported from Duty app.
//  Shows geographically accurate great circle route with proper positioning.
//

import SwiftUI
import CoreLocation

/// A custom-drawn flight route map showing:
/// - Geographically accurate airport positions (west on left, east on right)
/// - True great circle arc route between departure and arrival airports
/// - Airport markers with IATA codes, city names, and sun/moon icons
/// - Live aircraft position and heading when flight is in progress
/// - Flight distance in nautical miles and scheduled duration
struct FlightRouteMapView: View {
    let status: SharedPilotStatus

    @Environment(\.colorScheme) private var colorScheme

    private let airportProvider = AirportDataProvider.shared

    @State private var currentTime = Date()
    @State private var updateTimer: Timer?

    private let greatCirclePoints = 50
    private let mapPadding: CGFloat = 60

    // MARK: - Computed Properties

    private var departureAirport: AirportData? {
        guard let code = status.currentFlightDeparture else { return nil }
        return airportProvider.airportInfo(forIataCode: code)
    }

    private var arrivalAirport: AirportData? {
        guard let code = status.currentFlightArrival else { return nil }
        return airportProvider.airportInfo(forIataCode: code)
    }

    private var delayInterval: TimeInterval {
        status.hasFlightDelay ? TimeInterval((status.flightDelayMinutes ?? 0) * 60) : 0
    }

    private var isInFlight: Bool {
        guard let depTime = status.currentFlightDepartureTime,
              let arrTime = status.currentFlightArrivalTime else { return false }
        let adjustedDep = depTime.addingTimeInterval(delayInterval)
        let adjustedArr = arrTime.addingTimeInterval(delayInterval)
        return currentTime >= adjustedDep && currentTime <= adjustedArr
    }

    private var flightProgress: Double? {
        guard isInFlight,
              let depTime = status.currentFlightDepartureTime,
              let arrTime = status.currentFlightArrivalTime else { return nil }
        let adjustedDep = depTime.addingTimeInterval(delayInterval)
        let totalTime = arrTime.timeIntervalSince(depTime)
        guard totalTime > 0 else { return nil }
        let elapsed = currentTime.timeIntervalSince(adjustedDep)
        return min(max(elapsed / totalTime, 0.0), 1.0)
    }

    private var flightDistanceNM: Int? {
        guard let dep = departureAirport, let arr = arrivalAirport else { return nil }
        let meters = haversineDistance(
            lat1: dep.latitude, lon1: dep.longitude,
            lat2: arr.latitude, lon2: arr.longitude
        )
        return Int(meters / 1852)
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let dep = departureAirport, let arr = arrivalAirport {
                    let bounds = calculateBounds(departure: dep, arrival: arr)

                    dayNightBackground(departure: dep, arrival: arr, bounds: bounds, size: geometry.size)

                    greatCircleRoute(in: geometry.size, from: dep, to: arr, bounds: bounds)

                    geographicAirportMarkers(in: geometry.size, departure: dep, arrival: arr, bounds: bounds)

                    if let progress = flightProgress {
                        geographicAircraftMarker(in: geometry.size, from: dep, to: arr, bounds: bounds, progress: progress)
                    }

                    distanceLabel
                        .position(x: geometry.size.width / 2, y: geometry.size.height - 20)
                } else {
                    fallbackBackground
                    fallbackView
                }
            }
        }
        .frame(height: 200)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 20))
        .onAppear { startTimerIfNeeded() }
        .onDisappear { stopTimer() }
    }

    // MARK: - Geographic Bounds

    private struct GeoBounds {
        let minLat: Double
        let maxLat: Double
        let minLon: Double
        let maxLon: Double
        let longitudeOffset: Double

        var crossesAntimeridian: Bool { longitudeOffset != 0 }
        var lonSpan: Double { maxLon - minLon }
        var latSpan: Double { maxLat - minLat }

        init(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double, longitudeOffset: Double = 0) {
            self.minLat = minLat
            self.maxLat = maxLat
            self.minLon = minLon
            self.maxLon = maxLon
            self.longitudeOffset = longitudeOffset
        }
    }

    private func normalizeLongitude(_ lon: Double, offset: Double) -> Double {
        if offset != 0 && lon < 0 { return lon + offset }
        return lon
    }

    private func routeCrossesAntimeridian(departure: AirportData, arrival: AirportData) -> Bool {
        let depLon = departure.longitude
        let arrLon = arrival.longitude
        if (depLon >= 0 && arrLon >= 0) || (depLon < 0 && arrLon < 0) { return false }
        let eastwardDistance = abs(arrLon - depLon)
        let westwardDistance = 360 - eastwardDistance
        return westwardDistance < eastwardDistance
    }

    private func calculateBounds(departure: AirportData, arrival: AirportData) -> GeoBounds {
        let crossesAntimeridian = routeCrossesAntimeridian(departure: departure, arrival: arrival)
        let longitudeOffset: Double = crossesAntimeridian ? 360.0 : 0.0

        let pathPoints = generateGreatCirclePoints(
            from: CLLocationCoordinate2D(latitude: departure.latitude, longitude: departure.longitude),
            to: CLLocationCoordinate2D(latitude: arrival.latitude, longitude: arrival.longitude),
            count: greatCirclePoints
        )

        let depLonNorm = normalizeLongitude(departure.longitude, offset: longitudeOffset)
        let arrLonNorm = normalizeLongitude(arrival.longitude, offset: longitudeOffset)

        var minLat = min(departure.latitude, arrival.latitude)
        var maxLat = max(departure.latitude, arrival.latitude)
        var minLon = min(depLonNorm, arrLonNorm)
        var maxLon = max(depLonNorm, arrLonNorm)

        for point in pathPoints {
            minLat = min(minLat, point.latitude)
            maxLat = max(maxLat, point.latitude)
            let normalizedLon = normalizeLongitude(point.longitude, offset: longitudeOffset)
            minLon = min(minLon, normalizedLon)
            maxLon = max(maxLon, normalizedLon)
        }

        let latPadding = (maxLat - minLat) * 0.15
        let lonPadding = (maxLon - minLon) * 0.15
        minLat -= latPadding
        maxLat += latPadding
        minLon -= lonPadding
        maxLon += lonPadding

        let latSpan = maxLat - minLat
        let lonSpan = maxLon - minLon
        if lonSpan < latSpan * 0.5 {
            let targetLonSpan = latSpan * 0.6
            let extraPadding = (targetLonSpan - lonSpan) / 2
            minLon -= extraPadding
            maxLon += extraPadding
        }

        return GeoBounds(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon, longitudeOffset: longitudeOffset)
    }

    private func projectToView(lat: Double, lon: Double, bounds: GeoBounds, size: CGSize) -> CGPoint {
        let drawWidth = size.width - (mapPadding * 2)
        let drawHeight = size.height - (mapPadding * 2)
        let normalizedLon = normalizeLongitude(lon, offset: bounds.longitudeOffset)

        let normalizedX: Double = bounds.lonSpan <= 0 ? 0.5 : (normalizedLon - bounds.minLon) / bounds.lonSpan
        let normalizedY: Double = bounds.latSpan <= 0 ? 0.5 : (lat - bounds.minLat) / bounds.latSpan

        let x = mapPadding + (normalizedX * drawWidth)
        let y = mapPadding + ((1 - normalizedY) * drawHeight)
        return CGPoint(x: x, y: y)
    }

    // MARK: - View Components

    private var dayGradientColors: [Color] {
        colorScheme == .dark ? [
            Color(red: 0.12, green: 0.18, blue: 0.30),
            Color(red: 0.10, green: 0.15, blue: 0.26)
        ] : [
            Color(red: 0.85, green: 0.92, blue: 0.98),
            Color(red: 0.75, green: 0.85, blue: 0.95)
        ]
    }

    private var nightGradientColors: [Color] {
        colorScheme == .dark ? [
            Color(red: 0.04, green: 0.08, blue: 0.16),
            Color(red: 0.02, green: 0.05, blue: 0.12)
        ] : [
            Color(red: 0.70, green: 0.80, blue: 0.92),
            Color(red: 0.65, green: 0.75, blue: 0.88)
        ]
    }

    private func dayNightBackground(departure: AirportData, arrival: AirportData, bounds: GeoBounds, size: CGSize) -> some View {
        let depPoint = projectToView(lat: departure.latitude, lon: departure.longitude, bounds: bounds, size: size)
        let arrPoint = projectToView(lat: arrival.latitude, lon: arrival.longitude, bounds: bounds, size: size)

        let rawDepTime = status.currentFlightDepartureTime ?? Date()
        let rawArrTime = status.currentFlightArrivalTime ?? Date()
        let depTime = rawDepTime.addingTimeInterval(delayInterval)
        let arrTime = rawArrTime.addingTimeInterval(delayInterval)

        let depSunUp = isSunUp(lat: departure.latitude, lon: departure.longitude, at: depTime)
        let arrSunUp = isSunUp(lat: arrival.latitude, lon: arrival.longitude, at: arrTime)

        let depX = depPoint.x / size.width
        let arrX = arrPoint.x / size.width

        if depSunUp == arrSunUp {
            let colors = depSunUp ? dayGradientColors : nightGradientColors
            return AnyView(
                LinearGradient(gradient: Gradient(colors: colors), startPoint: .top, endPoint: .bottom)
            )
        }

        let leftColor = depX < arrX
            ? (depSunUp ? dayGradientColors[0] : nightGradientColors[0])
            : (arrSunUp ? dayGradientColors[0] : nightGradientColors[0])
        let rightColor = depX < arrX
            ? (arrSunUp ? dayGradientColors[0] : nightGradientColors[0])
            : (depSunUp ? dayGradientColors[0] : nightGradientColors[0])

        if let transition = findSolarTransitionPoint(departure: departure, arrival: arrival) {
            let transitionX = depX + (arrX - depX) * transition.progress
            let transitionWidth: CGFloat = 0.15
            let beforeTransition = max(0, transitionX - transitionWidth / 2)
            let afterTransition = min(1, transitionX + transitionWidth / 2)

            return AnyView(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: leftColor, location: 0),
                        .init(color: leftColor, location: beforeTransition),
                        .init(color: rightColor, location: afterTransition),
                        .init(color: rightColor, location: 1)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        } else {
            return AnyView(
                LinearGradient(gradient: Gradient(colors: [leftColor, rightColor]), startPoint: .leading, endPoint: .trailing)
            )
        }
    }

    private var fallbackBackground: some View {
        LinearGradient(gradient: Gradient(colors: dayGradientColors), startPoint: .top, endPoint: .bottom)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .gray : Color(red: 0.4, green: 0.4, blue: 0.45)
    }

    private func greatCircleRoute(in size: CGSize, from departure: AirportData, to arrival: AirportData, bounds: GeoBounds) -> some View {
        let geoPoints = generateGreatCirclePoints(
            from: CLLocationCoordinate2D(latitude: departure.latitude, longitude: departure.longitude),
            to: CLLocationCoordinate2D(latitude: arrival.latitude, longitude: arrival.longitude),
            count: greatCirclePoints
        )

        let viewPoints = geoPoints.map { coord in
            projectToView(lat: coord.latitude, lon: coord.longitude, bounds: bounds, size: size)
        }

        let routePath = Path { p in
            guard let first = viewPoints.first else { return }
            p.move(to: first)
            for point in viewPoints.dropFirst() {
                p.addLine(to: point)
            }
        }

        let arrowAngle: Double
        let arrowPosition: CGPoint
        if viewPoints.count >= 3 {
            let midIndex = viewPoints.count / 2
            let beforeMid = viewPoints[midIndex - 1]
            let atMid = viewPoints[midIndex]
            arrowAngle = atan2(atMid.y - beforeMid.y, atMid.x - beforeMid.x)
            arrowPosition = atMid
        } else if viewPoints.count >= 2 {
            let first = viewPoints[0]
            let last = viewPoints[1]
            arrowAngle = atan2(last.y - first.y, last.x - first.x)
            arrowPosition = CGPoint(x: (first.x + last.x) / 2, y: (first.y + last.y) / 2)
        } else {
            arrowAngle = 0
            arrowPosition = viewPoints.first ?? .zero
        }

        let arrowSize: CGFloat = 12
        let arrowPath = Path { p in
            let tipX = arrowPosition.x + cos(arrowAngle) * arrowSize
            let tipY = arrowPosition.y + sin(arrowAngle) * arrowSize
            let leftX = arrowPosition.x + cos(arrowAngle + 2.5) * arrowSize * 0.8
            let leftY = arrowPosition.y + sin(arrowAngle + 2.5) * arrowSize * 0.8
            let rightX = arrowPosition.x + cos(arrowAngle - 2.5) * arrowSize * 0.8
            let rightY = arrowPosition.y + sin(arrowAngle - 2.5) * arrowSize * 0.8
            p.move(to: CGPoint(x: leftX, y: leftY))
            p.addLine(to: CGPoint(x: tipX, y: tipY))
            p.addLine(to: CGPoint(x: rightX, y: rightY))
        }

        let routeColor = colorScheme == .dark ? Color.cyan : Color.blue
        let routeOpacity = colorScheme == .dark ? 0.8 : 1.0

        return ZStack {
            routePath
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            routeColor.opacity(routeOpacity * 0.75),
                            routeColor.opacity(routeOpacity),
                            routeColor.opacity(routeOpacity * 0.75)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: routeColor.opacity(0.5), radius: 4, x: 0, y: 0)

            arrowPath
                .stroke(routeColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .shadow(color: routeColor.opacity(0.8), radius: 4, x: 0, y: 0)
        }
    }

    private func geographicAirportMarkers(in size: CGSize, departure: AirportData, arrival: AirportData, bounds: GeoBounds) -> some View {
        let depPoint = projectToView(lat: departure.latitude, lon: departure.longitude, bounds: bounds, size: size)
        let arrPoint = projectToView(lat: arrival.latitude, lon: arrival.longitude, bounds: bounds, size: size)
        let depIsLeft = depPoint.x < arrPoint.x

        let rawDepTime = status.currentFlightDepartureTime ?? Date()
        let rawArrTime = status.currentFlightArrivalTime ?? Date()
        let delay: TimeInterval = status.hasFlightDelay ? TimeInterval((status.flightDelayMinutes ?? 0) * 60) : 0
        let depTime = rawDepTime.addingTimeInterval(delay)
        let arrTime = rawArrTime.addingTimeInterval(delay)

        let depSunUp = isSunUp(lat: departure.latitude, lon: departure.longitude, at: depTime)
        let arrSunUp = isSunUp(lat: arrival.latitude, lon: arrival.longitude, at: arrTime)

        let depLocalTime = formatLocalTime(date: depTime, timezoneId: status.currentTimezone)
        let arrLocalTime = formatLocalTime(date: arrTime, timezoneId: status.currentFlightArrivalTimezone)

        return ZStack {
            airportMarker(
                code: status.currentFlightDeparture ?? "???",
                cityName: departure.city,
                isOnLeft: depIsLeft,
                isDaylight: depSunUp,
                localTime: depLocalTime
            )
            .position(depPoint)

            airportMarker(
                code: status.currentFlightArrival ?? "???",
                cityName: arrival.city,
                isOnLeft: !depIsLeft,
                isDaylight: arrSunUp,
                localTime: arrLocalTime
            )
            .position(arrPoint)
        }
    }

    private func airportMarker(code: String, cityName: String, isOnLeft: Bool, isDaylight: Bool, localTime: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: isDaylight ? "sun.max.fill" : "moon.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isDaylight ? .yellow : .blue)
                .shadow(color: (isDaylight ? Color.yellow : Color.blue).opacity(0.8), radius: 4, x: 0, y: 0)

            Text(code)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(primaryTextColor)

            Text(cityName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(secondaryTextColor)
                .lineLimit(1)

            if !localTime.isEmpty {
                Text(localTime)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(primaryTextColor)
                    .lineLimit(1)
            }
        }
    }

    private func geographicAircraftMarker(in size: CGSize, from departure: AirportData, to arrival: AirportData, bounds: GeoBounds, progress: Double) -> some View {
        let aircraftCoord = interpolateGreatCircle(
            from: CLLocationCoordinate2D(latitude: departure.latitude, longitude: departure.longitude),
            to: CLLocationCoordinate2D(latitude: arrival.latitude, longitude: arrival.longitude),
            fraction: progress
        )

        let position = projectToView(lat: aircraftCoord.latitude, lon: aircraftCoord.longitude, bounds: bounds, size: size)

        let lookAheadProgress = min(progress + 0.02, 1.0)
        let lookAheadCoord = interpolateGreatCircle(
            from: CLLocationCoordinate2D(latitude: departure.latitude, longitude: departure.longitude),
            to: CLLocationCoordinate2D(latitude: arrival.latitude, longitude: arrival.longitude),
            fraction: lookAheadProgress
        )

        let distanceToLookAhead = haversineDistance(
            lat1: aircraftCoord.latitude, lon1: aircraftCoord.longitude,
            lat2: lookAheadCoord.latitude, lon2: lookAheadCoord.longitude
        )

        let isLookAheadTooClose = (lookAheadProgress == progress) || (distanceToLookAhead < 100.0)

        let bearing: Double
        if isLookAheadTooClose {
            let lookBehindProgress = max(progress - 0.02, 0.0)
            let lookBehindCoord = interpolateGreatCircle(
                from: CLLocationCoordinate2D(latitude: departure.latitude, longitude: departure.longitude),
                to: CLLocationCoordinate2D(latitude: arrival.latitude, longitude: arrival.longitude),
                fraction: lookBehindProgress
            )
            bearing = calculateBearing(from: lookBehindCoord, to: aircraftCoord)
        } else {
            bearing = calculateBearing(from: aircraftCoord, to: lookAheadCoord)
        }

        let screenRotation = bearing - 90

        return ZStack {
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 30, height: 30)
                .blur(radius: 8)

            Image(systemName: "airplane")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(primaryTextColor)
                .rotationEffect(.degrees(screenRotation))
                .shadow(color: Color.blue.opacity(0.8), radius: 4, x: 0, y: 0)
        }
        .position(position)
    }

    private var distanceLabel: some View {
        Group {
            if let distance = flightDistanceNM {
                HStack(spacing: 8) {
                    if let depTime = status.currentFlightDepartureTime,
                       let arrTime = status.currentFlightArrivalTime {
                        let duration = arrTime.timeIntervalSince(depTime)
                        if duration > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "timer")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue)
                                Text(formatDuration(duration))
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(primaryTextColor)
                            }
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.and.right")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                        Text("\(distance) nm")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(primaryTextColor)
                    }
                }
            }
        }
    }

    private var fallbackView: some View {
        VStack(spacing: 8) {
            Image(systemName: "airplane")
                .font(.system(size: 24))
                .foregroundColor(secondaryTextColor)

            Text("\(status.currentFlightDeparture ?? "???") → \(status.currentFlightArrival ?? "???")")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(secondaryTextColor)
        }
    }

    // MARK: - Great Circle Calculations

    private func generateGreatCirclePoints(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, count: Int) -> [CLLocationCoordinate2D] {
        (0...count).map { i in
            interpolateGreatCircle(from: start, to: end, fraction: Double(i) / Double(count))
        }
    }

    private func interpolateGreatCircle(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, fraction: Double) -> CLLocationCoordinate2D {
        let lat1 = start.latitude * .pi / 180
        let lon1 = start.longitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let lon2 = end.longitude * .pi / 180

        let cosD = sin(lat1) * sin(lat2) + cos(lat1) * cos(lat2) * cos(lon2 - lon1)
        let d = acos(min(1.0, max(-1.0, cosD)))
        if d < 0.0001 { return start }

        let a = sin((1 - fraction) * d) / sin(d)
        let b = sin(fraction * d) / sin(d)

        let x = a * cos(lat1) * cos(lon1) + b * cos(lat2) * cos(lon2)
        let y = a * cos(lat1) * sin(lon1) + b * cos(lat2) * sin(lon2)
        let z = a * sin(lat1) + b * sin(lat2)

        return CLLocationCoordinate2D(
            latitude: atan2(z, sqrt(x * x + y * y)) * 180 / .pi,
            longitude: atan2(y, x) * 180 / .pi
        )
    }

    // MARK: - Helper Methods

    private func calculateBearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let lat1 = start.latitude * .pi / 180
        let lon1 = start.longitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let lon2 = end.longitude * .pi / 180
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    private func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371000.0
        let phi1 = lat1 * .pi / 180
        let phi2 = lat2 * .pi / 180
        let deltaPhi = (lat2 - lat1) * .pi / 180
        let deltaLambda = (lon2 - lon1) * .pi / 180
        let a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
                cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2)
        return R * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    private func startTimerIfNeeded() {
        guard let depTime = status.currentFlightDepartureTime,
              let arrTime = status.currentFlightArrivalTime else { return }
        let now = Date()
        let oneHourFromNow = now.addingTimeInterval(3600)
        let adjustedArr = arrTime.addingTimeInterval(delayInterval)
        let adjustedDep = depTime.addingTimeInterval(delayInterval)
        if adjustedArr > now && adjustedDep < oneHourFromNow {
            updateTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
                currentTime = Date()
            }
        }
    }

    private func stopTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    // MARK: - Timezone and Local Time

    private func formatLocalTime(date: Date, timezoneId: String?) -> String {
        guard let id = timezoneId, let timeZone = TimeZone(identifier: id) else { return "" }

        let dayFormatter = DateFormatter()
        dayFormatter.timeZone = timeZone
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.dateFormat = "EEEE"
        let fullDay = dayFormatter.string(from: date).uppercased()
        let dayAbbr = String(fullDay.prefix(2))

        let timeFormatter = DateFormatter()
        timeFormatter.timeZone = timeZone
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "h:mma"

        return "\(dayAbbr) \(timeFormatter.string(from: date))"
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return String(format: "%d:%02d", hours, minutes)
        }
        return "\(minutes)m"
    }

    // MARK: - Solar Calculations

    private func sunAltitude(lat: Double, lon: Double, at date: Date) -> Double {
        let julianDay = date.timeIntervalSince1970 / 86400.0 + 2440587.5
        let n = julianDay - 2451545.0
        let L = (280.460 + 0.9856474 * n).truncatingRemainder(dividingBy: 360)
        let g = (357.528 + 0.9856003 * n).truncatingRemainder(dividingBy: 360) * .pi / 180
        let eclipticLongitude = L + 1.915 * sin(g) + 0.020 * sin(2 * g)
        let epsilon = (23.439 - 0.0000004 * n) * .pi / 180
        let sunDeclination = asin(sin(epsilon) * sin(eclipticLongitude * .pi / 180))
        let E = 4 * (L - eclipticLongitude) - 1.915 * sin(g) * 57.3
        let hours = date.timeIntervalSince1970.truncatingRemainder(dividingBy: 86400) / 3600.0
        let subsolarLongitude = -(hours - 12.0) * 15.0 + (E / 4.0)
        var hourAngleDeg = lon - subsolarLongitude
        while hourAngleDeg > 180 { hourAngleDeg -= 360 }
        while hourAngleDeg < -180 { hourAngleDeg += 360 }
        let hourAngle = hourAngleDeg * .pi / 180
        let latRad = lat * .pi / 180
        let altitude = asin(sin(latRad) * sin(sunDeclination) + cos(latRad) * cos(sunDeclination) * cos(hourAngle))
        return altitude * 180 / .pi
    }

    private func isSunUp(lat: Double, lon: Double, at date: Date) -> Bool {
        sunAltitude(lat: lat, lon: lon, at: date) > -0.833
    }

    private func findSolarTransitionPoint(departure: AirportData, arrival: AirportData) -> (progress: Double, isSunrise: Bool)? {
        guard let rawDepTime = status.currentFlightDepartureTime,
              let rawArrTime = status.currentFlightArrivalTime else { return nil }
        let depTime = rawDepTime.addingTimeInterval(delayInterval)
        let arrTime = rawArrTime.addingTimeInterval(delayInterval)
        let flightDuration = arrTime.timeIntervalSince(depTime)
        guard flightDuration > 1800 else { return nil }

        let sampleInterval: TimeInterval = 300
        let numSamples = Int(flightDuration / sampleInterval)
        guard numSamples > 1 else { return nil }

        var previousSunUp: Bool? = nil
        for i in 0...numSamples {
            let progress = Double(i) / Double(numSamples)
            let sampleTime = depTime.addingTimeInterval(flightDuration * progress)
            let position = interpolateGreatCircle(
                from: CLLocationCoordinate2D(latitude: departure.latitude, longitude: departure.longitude),
                to: CLLocationCoordinate2D(latitude: arrival.latitude, longitude: arrival.longitude),
                fraction: progress
            )
            let sunUp = isSunUp(lat: position.latitude, lon: position.longitude, at: sampleTime)
            if let prevSunUp = previousSunUp, sunUp != prevSunUp {
                let transitionProgress = (Double(i) - 0.5) / Double(numSamples)
                return (progress: transitionProgress, isSunrise: sunUp)
            }
            previousSunUp = sunUp
        }
        return nil
    }
}
