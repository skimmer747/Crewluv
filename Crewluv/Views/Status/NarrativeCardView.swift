//
//  NarrativeCardView.swift
//  CrewLuve
//
//  "What's happening now" narrative card with live countdown
//

import SwiftUI
import Combine

struct NarrativeCardView: View {
    let status: SharedPilotStatus
    var upcomingTrip: UpcomingTripInfo? = nil

    @Environment(\.colorScheme) private var colorScheme
    @State private var now = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 14) {
            statusIconView

            narrativeText
                .font(.body)
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .onReceive(timer) { _ in
            withAnimation(.snappy(duration: 0.3)) {
                now = Date()
            }
        }
    }

    // MARK: - Narrative Text

    @ViewBuilder
    private var narrativeText: some View {
        switch status.displayStatus {
        case .home:
            homeNarrative
        case .commutingHome:
            commutingHomeNarrative
        case .drivingHome:
            drivingNarrative(toHome: true)
        case .drivingToWork:
            drivingNarrative(toHome: false)
        case .inFlight:
            inFlightNarrative
        case .turn:
            turnNarrative
        case .layover:
            layoverNarrative
        case .reserve:
            reserveNarrative
        case .hotStandby:
            hotStandbyNarrative
        case .training:
            trainingNarrative
        case .base:
            baseNarrative
        case .elsewhere(let city):
            elsewhereNarrative(city: city)
        case .unknown:
            Text("On duty")
        }
    }

    private var name: String { status.pilotFirstName }

    /// The arrival date of the first future flight back to the home airport,
    /// scanning all trip legs (not just the immediate next trip).
    private var homecomingDate: Date? {
        guard let home = status.homeAirportCode,
              let trip = upcomingTrip else { return nil }
        return status.tripLegs
            .filter { $0.type == .flight && $0.endTime > trip.departureDate && $0.arrivalAirport == home }
            .min(by: { $0.startTime < $1.startTime })
            .map(\.endTime)
    }

    /// Live countdown + arrival date for when the pilot gets home, e.g.
    /// "back home in **6d 4h 34m** on **April 4th at 6:31pm**"
    /// Returns nil when no homecoming flight is found (falls back to per-trip duration).
    private var homecomingText: Text? {
        guard let arrival = homecomingDate else { return nil }
        let countdown = countdownText(to: arrival, color: .green)
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE MMMM d"
        let monthDay = formatter.string(from: arrival)
        let day = Calendar.current.component(.day, from: arrival)
        let suffix = ordinalSuffix(for: day)
        let timeStr = formattedLocalTime(arrival)
        let dateText = Text("\(monthDay)\(suffix) at \(timeStr)").bold()
        return Text("Back home in \(countdown) on \(dateText)")
    }

    private var homeNarrative: Text {
        let hasPrevTrip = status.lastTripDurationDays != nil
        let hasNextTrip = upcomingTrip != nil

        let base: Text
        if hasPrevTrip, let days = status.lastTripDurationDays, hasNextTrip, let trip = upcomingTrip {
            let depText = formattedDepartureDate(trip.departureDate)
            let durationText = Text("\(trip.durationDays) \(trip.durationDays == 1 ? "day" : "days")").bold()
            let prevText = Text("\(days) \(days == 1 ? "day" : "days")").bold()
            if let commuteCity = trip.commuteCity {
                let dest = trip.firstDestinationCity ?? trip.cityRoute.last ?? "work"
                if let homecoming = homecomingText {
                    base = Text("\(name) is home after being gone for \(prevText)! Commuting to \(Text(commuteCity).bold()) then heading to \(Text(dest).bold()) \(depText). \(homecoming).")
                } else {
                    base = Text("\(name) is home after being gone for \(prevText)! Commuting to \(Text(commuteCity).bold()) then heading to \(Text(dest).bold()) \(depText) — gone for \(durationText).")
                }
            } else {
                let dest = trip.firstDestinationCity ?? trip.cityRoute.first ?? "work"
                if let homecoming = homecomingText {
                    base = Text("\(name) is home after being gone for \(prevText)! Heading to \(Text(dest).bold()) \(depText). \(homecoming).")
                } else {
                    base = Text("\(name) is home after being gone for \(prevText)! Heading to \(Text(dest).bold()) \(depText) — gone for \(durationText).")
                }
            }
        } else if hasPrevTrip, let days = status.lastTripDurationDays {
            base = Text("\(name) is home after being gone for \(Text("\(days) \(days == 1 ? "day" : "days")").bold()) and is relaxing.")
        } else if hasNextTrip, let trip = upcomingTrip {
            let depText = formattedDepartureDate(trip.departureDate)
            let durationText = Text("\(trip.durationDays) \(trip.durationDays == 1 ? "day" : "days")").bold()
            if let commuteCity = trip.commuteCity {
                let dest = trip.firstDestinationCity ?? trip.cityRoute.last ?? "work"
                if let homecoming = homecomingText {
                    base = Text("\(name) is home — commutes to \(Text(commuteCity).bold()) then heads to \(Text(dest).bold()) \(depText). \(homecoming).")
                } else {
                    base = Text("\(name) is home — commutes to \(Text(commuteCity).bold()) then heads to \(Text(dest).bold()) \(depText) and will be gone for \(durationText).")
                }
            } else {
                let dest = trip.firstDestinationCity ?? trip.cityRoute.first ?? "work"
                if let homecoming = homecomingText {
                    base = Text("\(name) is home — heads to \(Text(dest).bold()) \(depText). \(homecoming).")
                } else {
                    base = Text("\(name) is home — heads to \(Text(dest).bold()) \(depText) and will be gone for \(durationText).")
                }
            }
        } else {
            base = Text("\(name) is home and relaxing.")
        }

        guard status.hasFlightDelay, let leg = status.delayedFlightLeg,
              let delay = leg.delayMinutes else { return base }
        let dest = leg.arrivalCity ?? leg.arrivalAirport ?? "destination"
        let delayStr = formattedDelayDuration(delay)
        return Text("\(base) The flight to \(Text(dest).bold()) is delayed \(Text(delayStr).bold()).")
    }

    @ViewBuilder
    private var commutingHomeNarrative: some View {
        if let js = nextFlight() {
            let from = js.departureCity ?? status.currentCity ?? "here"
            let to = js.arrivalCity ?? "home"
            let depTimeStr = formattedLocalTime(js.startTime)
            let arrTimeStr = formattedLocalTime(js.endTime)
            Text("\(name) has one more leg home from \(Text(from).bold()) to \(Text(to).bold())! It leaves in \(countdownText(to: js.startTime)) at \(Text(depTimeStr).bold()) and lands at \(Text(arrTimeStr).bold()).")
        } else {
            Text("\(name) is heading home")
        }
    }

    @ViewBuilder
    private func drivingNarrative(toHome: Bool) -> some View {
        let drive = activeDriveLeg()
        let destCity = drive?.arrivalCity
            ?? AirportDataProvider.shared.airportInfo(forIataCode: drive?.arrivalAirport ?? "")?.city
            ?? (toHome ? "home" : "work")
        if let arrival = drive?.endTime ?? status.homeArrivalTime {
            let arrTimeStr = formattedLocalTime(arrival)
            if toHome {
                Text("\(name) is driving home to \(Text(destCity).bold()) — back in \(countdownText(to: arrival, color: .green)) at \(Text(arrTimeStr).bold()).")
            } else {
                Text("\(name) is driving to work in \(Text(destCity).bold()) — arrives in \(countdownText(to: arrival)) at \(Text(arrTimeStr).bold()), then the trip starts.")
            }
        } else {
            Text(toHome ? "\(name) is driving home" : "\(name) is driving to work")
        }
    }

    /// The drive leg currently in progress (startTime <= now < endTime), if any.
    private func activeDriveLeg() -> TripLeg? {
        sortedTripLegs.first(where: { $0.type == .drive && $0.startTime <= now && now < $0.endTime })
    }

    // MARK: - Date Formatting Helpers

    private func formattedDepartureDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mma"
        timeFormatter.amSymbol = "am"
        timeFormatter.pmSymbol = "pm"
        let timeStr = timeFormatter.string(from: date)

        if calendar.isDateInToday(date) {
            return "today at \(timeStr)"
        } else if calendar.isDateInTomorrow(date) {
            return "tomorrow at \(timeStr)"
        } else {
            let weekday = date.formatted(.dateTime.weekday(.wide))
            let day = calendar.component(.day, from: date)
            let suffix = ordinalSuffix(for: day)
            return "\(weekday) the \(day)\(suffix) at \(timeStr)"
        }
    }

    private func ordinalSuffix(for day: Int) -> String {
        let teens = (11...13).contains(day % 100)
        if teens { return "th" }
        switch day % 10 {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }

    @ViewBuilder
    private var inFlightNarrative: some View {
        let verb = currentFlightIsCommercial ? "riding" : "flying"
        if status.hasFlightDelay, let delayMinutes = status.effectiveFlightDelayMinutes {
            // Flight-time-change narrative (delayed or early)
            let isEarly = status.isEarlyDeparture
            let statePhrase = isEarly ? "is pushing early" : "is delayed"
            let pastPhrase = isEarly ? "pushed early" : "was delayed"
            let countdownColor: Color = isEarly ? .green : .red
            let dest = currentArrivalCity()
            let dep = currentDepartureCity()
            let fltStr = formattedFlightString(status.currentFlightNumber)

            if let depTime = status.currentFlightDepartureTime {
                let shiftedDep = depTime.addingTimeInterval(TimeInterval(delayMinutes * 60))
                if now < shiftedDep {
                    if let dep, let dest {
                        Text("\(name) \(statePhrase) in \(Text(dep).bold()) and will be \(verb) to \(Text(dest).bold())\(fltStr) — departing in \(countdownText(to: shiftedDep)).")
                    } else if let dest {
                        Text("\(name) \(statePhrase) and will be \(verb) to \(Text(dest).bold())\(fltStr) — departing in \(countdownText(to: shiftedDep)).")
                    } else {
                        Text("\(name)'s flight \(statePhrase) — departing in \(countdownText(to: shiftedDep))")
                    }
                } else if let arrTime = status.currentFlightArrivalTime {
                    let shiftedArr = arrTime.addingTimeInterval(TimeInterval(delayMinutes * 60))
                    let arrTimeStr = formattedLocalTime(shiftedArr)
                    if let dep, let dest {
                        Text("\(name) \(pastPhrase) in \(Text(dep).bold()) and is \(verb) to \(Text(dest).bold())\(fltStr) — landing in \(countdownText(to: shiftedArr, color: countdownColor)) which is \(Text(arrTimeStr).bold()).")
                    } else if let dest {
                        Text("\(name)'s flight to \(Text(dest).bold())\(fltStr) — landing in \(countdownText(to: shiftedArr, color: countdownColor)) which is \(Text(arrTimeStr).bold()).")
                    } else {
                        Text("\(name)'s flight — landing in \(countdownText(to: shiftedArr, color: countdownColor)) which is \(Text(arrTimeStr).bold()).")
                    }
                } else if let dest {
                    Text("\(name)'s flight to \(Text(dest).bold())\(fltStr)")
                } else {
                    Text("\(name)'s flight \(statePhrase)")
                }
            } else if let dest {
                Text("\(name)'s flight to \(Text(dest).bold()) \(statePhrase)")
            } else {
                Text("\(name)'s flight \(statePhrase)")
            }
        } else if let dest = currentArrivalCity(), let arrTime = status.currentFlightArrivalTime {
            let fltStr = formattedFlightString(status.currentFlightNumber)
            let dep = currentDepartureCity()
            let arrTimeStr = formattedLocalTime(arrTime)
            if let dep {
                Text("\(name) is \(verb) to \(Text(dest).bold())\(fltStr) from \(Text(dep).bold()) — landing in \(countdownText(to: arrTime)) which is \(Text(arrTimeStr).bold()).")
            } else {
                Text("\(name) is \(verb) to \(Text(dest).bold())\(fltStr) — landing in \(countdownText(to: arrTime)) which is \(Text(arrTimeStr).bold()).")
            }
        } else if let dest = currentArrivalCity() {
            Text("\(name) is \(verb) to \(Text(dest).bold())")
        } else {
            Text("\(name) is in flight")
        }
    }

    @ViewBuilder
    private var turnNarrative: some View {
        if status.hasFlightDelay, let delayMinutes = status.effectiveFlightDelayMinutes {
            // Time-change-aware turn narrative with shifted departure time
            let isEarly = status.isEarlyDeparture
            let statePhrase = isEarly ? "is pushing early" : "is delayed"
            let countdownColor: Color = isEarly ? .green : .red
            if let city = status.currentCity, let dest = nextFlightCity(), let nextTime = nextFlightDepartureTime() {
                let shiftedTime = nextTime.addingTimeInterval(TimeInterval(delayMinutes * 60))
                let depTimeStr = formattedLocalTime(shiftedTime)
                Text("\(name) \(statePhrase) in \(Text(city).bold()) — heading to \(Text(dest).bold()) in \(countdownText(to: shiftedTime, color: countdownColor)) which is \(Text(depTimeStr).bold()).")
            } else if let city = status.currentCity, let nextTime = nextFlightDepartureTime() {
                let shiftedTime = nextTime.addingTimeInterval(TimeInterval(delayMinutes * 60))
                let depTimeStr = formattedLocalTime(shiftedTime)
                Text("\(name) \(statePhrase) in \(Text(city).bold()) — next flight in \(countdownText(to: shiftedTime, color: countdownColor)) which is \(Text(depTimeStr).bold()).")
            } else if let city = status.currentCity {
                Text("\(name) \(statePhrase) in \(Text(city).bold()) between flights")
            } else {
                Text("\(name) \(statePhrase) between flights")
            }
        } else if let city = status.currentCity, let dest = nextFlightCity(), let nextTime = nextFlightDepartureTime() {
            let depTimeStr = formattedLocalTime(nextTime)
            Text("\(name) is in \(Text(city).bold()) — heading to \(Text(dest).bold()) in \(countdownText(to: nextTime)) which is \(Text(depTimeStr).bold()).")
        } else if let city = status.currentCity, let nextTime = nextFlightDepartureTime() {
            let depTimeStr = formattedLocalTime(nextTime)
            Text("\(name) is in \(Text(city).bold()) — next flight in \(countdownText(to: nextTime)) which is \(Text(depTimeStr).bold()).")
        } else if let city = status.currentCity {
            Text("\(name) is in \(Text(city).bold()) between flights")
        } else {
            Text("\(name) is between flights")
        }
    }

    @ViewBuilder
    private var layoverNarrative: some View {
        if status.hasFlightDelay, let delayMinutes = status.effectiveFlightDelayMinutes {
            // Time-change-aware layover narrative with human-readable offset and shifted departure
            let isEarly = status.isEarlyDeparture
            let delayStr = formattedDelayDuration(abs(delayMinutes))
            let changeVerb = isEarly ? "shortened" : "extended"
            let countdownColor: Color = isEarly ? .green : .red
            if let dest = nextFlightCity(), let nextTime = nextFlightDepartureTime() {
                let shiftedTime = nextTime.addingTimeInterval(TimeInterval(delayMinutes * 60))
                let depTimeStr = formattedLocalTime(shiftedTime)
                Text("\(name)'s layover has been \(changeVerb) by \(Text(delayStr).bold()) and will now fly to \(Text(dest).bold()) in \(countdownText(to: shiftedTime, color: countdownColor)) which is \(Text(depTimeStr).bold()).")
            } else if let nextTime = nextFlightDepartureTime() {
                let shiftedTime = nextTime.addingTimeInterval(TimeInterval(delayMinutes * 60))
                let depTimeStr = formattedLocalTime(shiftedTime)
                Text("\(name)'s layover has been \(changeVerb) by \(Text(delayStr).bold()) — next flight in \(countdownText(to: shiftedTime, color: countdownColor)) which is \(Text(depTimeStr).bold()).")
            } else if let city = status.currentCity {
                Text("\(name)'s layover in \(Text(city).bold()) has been \(changeVerb) by \(Text(delayStr).bold()).")
            } else {
                Text("\(name)'s layover has been \(changeVerb) by \(Text(delayStr).bold()).")
            }
        } else if let city = status.currentCity, let dest = nextFlightCity(), let nextTime = nextFlightDepartureTime() {
            let depTimeStr = formattedLocalTime(nextTime)
            Text("\(name) is on layover in \(Text(city).bold()) — flies to \(Text(dest).bold()) in \(countdownText(to: nextTime)) which is \(Text(depTimeStr).bold()).")
        } else if let city = status.currentCity, let nextTime = nextFlightDepartureTime() {
            let depTimeStr = formattedLocalTime(nextTime)
            Text("\(name) is on layover in \(Text(city).bold()) — next flight in \(countdownText(to: nextTime)) which is \(Text(depTimeStr).bold()).")
        } else if let city = status.currentCity {
            Text("\(name) is on layover in \(Text(city).bold())")
        } else {
            Text("\(name) is on layover")
        }
    }

    @ViewBuilder
    private var reserveNarrative: some View {
        if let city = status.currentCity, let endTime = status.homeArrivalTime {
            let endTimeStr = formattedLocalTime(endTime)
            Text("\(name) is on reserve in \(Text(city).bold()) — on call until \(countdownText(to: endTime)) which is \(Text(endTimeStr).bold()).")
        } else if let city = status.currentCity {
            Text("\(name) is on reserve in \(Text(city).bold())")
        } else {
            Text("\(name) is on reserve")
        }
    }

    @ViewBuilder
    private var hotStandbyNarrative: some View {
        if let city = status.currentCity, let endTime = status.homeArrivalTime {
            let endTimeStr = formattedLocalTime(endTime)
            Text("\(name) is on hot standby in \(Text(city).bold()) — on call until \(countdownText(to: endTime)) which is \(Text(endTimeStr).bold()).")
        } else if let city = status.currentCity {
            Text("\(name) is on hot standby in \(Text(city).bold())")
        } else {
            Text("\(name) is on hot standby")
        }
    }

    @ViewBuilder
    private var trainingNarrative: some View {
        if let eventTitle = activeEventLabel() {
            eventNarrative(title: eventTitle)
        } else if let city = status.currentCity, let endTime = status.homeArrivalTime {
            let endTimeStr = formattedLocalTime(endTime)
            Text("\(name) is in training in \(Text(city).bold()) — finishes in \(countdownText(to: endTime)) which is \(Text(endTimeStr).bold()).")
        } else if let city = status.currentCity {
            Text("\(name) is in training in \(Text(city).bold())")
        } else {
            Text("\(name) is in training")
        }
    }

    @ViewBuilder
    private func eventNarrative(title: String) -> some View {
        if let city = status.currentCity, let endTime = status.homeArrivalTime {
            let endTimeStr = formattedLocalTime(endTime)
            Text("\(name): \(Text(title).bold()) in \(Text(city).bold()) — finishes in \(countdownText(to: endTime)) which is \(Text(endTimeStr).bold()).")
        } else if let endTime = status.homeArrivalTime {
            let endTimeStr = formattedLocalTime(endTime)
            Text("\(name): \(Text(title).bold()) — finishes in \(countdownText(to: endTime)) which is \(Text(endTimeStr).bold()).")
        } else if let city = status.currentCity {
            Text("\(name): \(Text(title).bold()) in \(Text(city).bold())")
        } else {
            Text("\(name): \(Text(title).bold())")
        }
    }

    /// The trimmed label of the currently-active manual event leg, if any.
    /// Returns nil when no event leg covers `now` or the label is empty/whitespace —
    /// callers fall back to the generic "in training" copy.
    private func activeEventLabel() -> String? {
        let currentTime = now
        let activeEvent: TripLeg? = sortedTripLegs.first(where: { (leg: TripLeg) in
            leg.type == .event && leg.startTime <= currentTime && currentTime < leg.endTime
        })
        guard let raw = activeEvent?.label else { return nil }
        let trimmed = raw.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Picks an SF Symbol that better matches the active event's title, e.g.
    /// a car for "Driving the truck home". Returns nil to keep the default
    /// `book.fill` icon used for training-style events.
    private func eventIconOverride() -> String? {
        guard let label = activeEventLabel()?.lowercased() else { return nil }
        if label.contains("driv") || label.contains("truck") || label.contains("car") {
            return "car.fill"
        }
        return nil
    }

    /// Pilot is between trips at an airport that is neither home nor base.
    /// Surface the city as the headline; do not invent a status word.
    @ViewBuilder
    private func elsewhereNarrative(city resolverCity: String?) -> some View {
        if let city = resolverCity ?? status.currentCity {
            if let nextTime = nextFlightDepartureTime(), let dest = nextFlightCity() {
                let depTimeStr = formattedLocalTime(nextTime)
                Text("\(name) is in \(Text(city).bold()) — flies to \(Text(dest).bold()) in \(countdownText(to: nextTime)) which is \(Text(depTimeStr).bold()).")
            } else if let nextTime = nextFlightDepartureTime() {
                let depTimeStr = formattedLocalTime(nextTime)
                Text("\(name) is in \(Text(city).bold()) — next flight in \(countdownText(to: nextTime)) which is \(Text(depTimeStr).bold()).")
            } else {
                Text("\(name) is in \(Text(city).bold())")
            }
        } else if let code = status.currentAirport {
            Text("\(name) is in \(Text(code).bold())")
        } else {
            Text("\(name) is off duty")
        }
    }

    @ViewBuilder
    private var baseNarrative: some View {
        if let city = status.currentCity,
           let homeEvent = nextHomeEvent(),
           nextFlight().map({ homeEvent.startTime < $0.startTime }) ?? true {
            let homeCity = homeEvent.arrivalCity
                ?? AirportDataProvider.shared.airportInfo(forIataCode: homeEvent.arrivalAirport ?? "")?.city
                ?? "home"
            let depTimeStr = formattedLocalTime(homeEvent.startTime)
            Text("\(name) is at base in \(Text(city).bold()) — heads home to \(Text(homeCity).bold()) in \(countdownText(to: homeEvent.startTime)) which is \(Text(depTimeStr).bold()).")
        } else if let city = status.currentCity, let nextTime = nextFlightDepartureTime(), let dest = nextFlightCity() {
            let depTimeStr = formattedLocalTime(nextTime)
            Text("\(name) is at base in \(Text(city).bold()) — flies to \(Text(dest).bold()) in \(countdownText(to: nextTime)) which is \(Text(depTimeStr).bold()).")
        } else if let city = status.currentCity, let nextTime = nextFlightDepartureTime() {
            let depTimeStr = formattedLocalTime(nextTime)
            Text("\(name) is at base in \(Text(city).bold()) — next flight in \(countdownText(to: nextTime)) which is \(Text(depTimeStr).bold()).")
        } else if let city = status.currentCity {
            Text("\(name) is at base in \(Text(city).bold())")
        } else {
            Text("\(name) is at base")
        }
    }

    // MARK: - Status Icon with Progress Ring

    private var statusIconView: some View {
        ZStack {
            if status.displayStatus.isLayoverLike, let progress = layoverProgress {
                Circle()
                    .stroke(statusColor.opacity(0.2), lineWidth: 3)
                    .frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(statusColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
            } else if status.displayStatus.isDutyPeriod,
                      let progress = dutyPeriodProgress {
                Circle()
                    .stroke(statusColor.opacity(0.2), lineWidth: 3)
                    .frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(statusColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
            } else if status.displayStatus == .inFlight, let progress = flightProgress {
                Circle()
                    .stroke(statusColor.opacity(0.2), lineWidth: 3)
                    .frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(statusColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
            }

            Image(systemName: statusIcon)
                .font(.system(size: 28))
                .foregroundColor(statusColor)
        }
        .frame(width: 44)
    }

    private var flightProgress: Double? {
        let legs = sortedTripLegs
        guard !legs.isEmpty else { return nil }
        // Use per-leg delay: only extend the specifically-delayed flight
        var matchedFlight: TripLeg?
        for leg in legs where leg.type == .flight {
            let legDelay = TimeInterval((leg.delayMinutes ?? 0) * 60)
            if leg.startTime <= now && now < leg.endTime.addingTimeInterval(legDelay) {
                matchedFlight = leg
                break
            }
        }
        guard let flight = matchedFlight else { return nil }
        let legDelay = TimeInterval((flight.delayMinutes ?? 0) * 60)
        let adjustedStart = flight.startTime.addingTimeInterval(legDelay)
        let total = flight.endTime.timeIntervalSince(flight.startTime)
        guard total > 0 else { return nil }
        let elapsed = now.timeIntervalSince(adjustedStart)
        return min(max(elapsed / total, 0), 1)
    }

    private var layoverProgress: Double? {
        let legs = sortedTripLegs
        guard !legs.isEmpty else { return nil }
        guard let layover = legs.first(where: {
            ($0.type == .layover || $0.type == .base) && $0.startTime <= now && now < $0.endTime
        }) else { return nil }
        let total = layover.endTime.timeIntervalSince(layover.startTime)
        guard total > 0 else { return nil }
        let elapsed = now.timeIntervalSince(layover.startTime)
        return min(max(elapsed / total, 0), 1)
    }

    private var dutyPeriodProgress: Double? {
        let legs = sortedTripLegs
        guard !legs.isEmpty else { return nil }
        let dutyTypes: [TripLeg.LegType] = [.reserve, .hotStandby, .event]
        guard let duty = legs.first(where: {
            dutyTypes.contains($0.type) && $0.startTime <= now && now < $0.endTime
        }) else { return nil }
        let total = duty.endTime.timeIntervalSince(duty.startTime)
        guard total > 0 else { return nil }
        let elapsed = now.timeIntervalSince(duty.startTime)
        return min(max(elapsed / total, 0), 1)
    }

    // MARK: - Countdown Formatting

    private func countdownText(to target: Date, color: Color? = nil) -> Text {
        let resolvedColor = color ?? statusColor
        let interval = target.timeIntervalSince(now)
        guard interval > 0 else {
            return Text("now!").bold().foregroundColor(resolvedColor)
        }

        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        let minutes = (Int(interval) % 3600) / 60

        let formatted: String
        if days > 0 {
            formatted = "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            formatted = "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            formatted = "\(minutes)m"
        } else {
            // Under one minute: show a friendly floor so we don't flash "0m".
            formatted = "<1m"
        }
        return Text(formatted).bold().foregroundColor(resolvedColor).monospacedDigit()
    }

    // MARK: - City Name Helpers

    /// Sorted trip legs by start time (ascending) for consistent processing
    /// This ensures all helper methods reference the same sorted order
    private var sortedTripLegs: [TripLeg] {
        status.tripLegs.sorted { $0.startTime < $1.startTime }
    }

    /// Finds the next flight leg after the current time
    /// Uses sortedTripLegs to ensure consistent results across all helper methods
    /// Returns the first flight leg where startTime > now
    private func nextFlight() -> TripLeg? {
        sortedTripLegs.first(where: { $0.type == .flight && $0.startTime > now })
    }

    private func nextHomeEvent() -> TripLeg? {
        guard let home = status.homeAirportCode, !home.isEmpty else { return nil }
        return sortedTripLegs.first(where: {
            $0.type == .event
            && $0.startTime > now
            && $0.arrivalAirport?.caseInsensitiveCompare(home) == .orderedSame
        })
    }

    private func currentDepartureCity() -> String? {
        let legs = sortedTripLegs
        if !legs.isEmpty {
            // Use per-leg delay to extend only the specifically-delayed flight
            let currentFlight = legs.first(where: { (leg: TripLeg) in
                guard leg.type == .flight else { return false }
                let legDelay = TimeInterval((leg.delayMinutes ?? 0) * 60)
                return leg.startTime <= now && now < leg.endTime.addingTimeInterval(legDelay)
            })
            if let city = currentFlight?.departureCity, !city.isEmpty {
                return city
            }
        }
        if let code = status.currentFlightDeparture {
            return AirportDataProvider.shared.airportInfo(forIataCode: code)?.city
        }
        return nil
    }

    private func currentArrivalCity() -> String? {
        let legs = sortedTripLegs
        if !legs.isEmpty {
            // Use per-leg delay to extend only the specifically-delayed flight
            let currentFlight = legs.first(where: { (leg: TripLeg) in
                guard leg.type == .flight else { return false }
                let legDelay = TimeInterval((leg.delayMinutes ?? 0) * 60)
                return leg.startTime <= now && now < leg.endTime.addingTimeInterval(legDelay)
            })
            if let city = currentFlight?.arrivalCity, !city.isEmpty {
                return city
            }
        }
        // Look up city name from IATA code, consistent with currentDepartureCity()
        if let code = status.currentFlightArrival {
            return AirportDataProvider.shared.airportInfo(forIataCode: code)?.city ?? code
        }
        return nil
    }

    private func nextFlightCity() -> String? {
        let sorted = sortedTripLegs
        if !sorted.isEmpty {
            // Use the shared helper to get the next flight leg
            // This ensures consistency with nextFlightDepartureTime()
            let nextFlight = nextFlight()
            // Standalone jumpseat — chain through to the trip it connects to
            // If homeAirport is known, only chain if jumpseat departs from there
            if let js = nextFlight, js.tripId == nil,
               (status.homeAirportCode == nil || js.departureAirport == status.homeAirportCode),
               let jsArrival = js.arrivalAirport {
                if let tripFlight = sorted.first(where: {
                    $0.tripId != nil && $0.type == .flight &&
                    $0.startTime >= js.endTime &&
                    $0.departureAirport == jsArrival
                }), let city = tripFlight.arrivalCity, !city.isEmpty {
                    return city
                }
            }
            if let city = nextFlight?.arrivalCity, !city.isEmpty {
                return city
            }
        }
        return status.nextFlightDestination
    }

    private func nextFlightDepartureTime() -> Date? {
        // Use the shared helper to get the next flight leg
        // This ensures consistency with nextFlightCity() - both reference the same TripLeg instance
        if let nextFlight = nextFlight() {
            return nextFlight.startTime
        }
        return status.nextDepartureTime
    }

    /// Formats delay minutes as human-readable text, e.g. "10 hours", "2 hours 30 minutes", "45 minutes"
    private func formattedDelayDuration(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 {
            return "\(h) \(h == 1 ? "hour" : "hours") \(m) \(m == 1 ? "minute" : "minutes")"
        } else if h > 0 {
            return "\(h) \(h == 1 ? "hour" : "hours")"
        } else {
            return "\(m) \(m == 1 ? "minute" : "minutes")"
        }
    }

    /// Formats a date as local time with timezone abbreviation, e.g. "3:00pm EST"
    private func formattedLocalTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma z"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    // MARK: - Airline Helpers

    private var currentFlightIsCommercial: Bool {
        let legs = sortedTripLegs
        guard !legs.isEmpty else { return currentAirlineCode != nil }
        let currentFlight = legs.first { leg in
            guard leg.type == .flight else { return false }
            let legDelay = TimeInterval((leg.delayMinutes ?? 0) * 60)
            return leg.startTime <= now && now < leg.endTime.addingTimeInterval(legDelay)
        }
        return currentFlight?.airlineCode != nil
    }

    private var currentAirlineCode: String? {
        guard let flt = status.currentFlightNumber else { return nil }
        let (prefix, _) = FlightTrackingHelper.parseFlightNumber(flt)
        return prefix.isEmpty ? nil : prefix
    }

    private func formattedFlightString(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "" }
        let (prefix, number) = FlightTrackingHelper.parseFlightNumber(raw)
        guard !number.isEmpty else { return "" }
        let airline = AirlineBranding.airlineName(for: prefix)
        return " on \(airline) flight \(number)"
    }

    // MARK: - Status Icon & Color

    private var statusIcon: String {
        switch status.displayStatus {
        case .home: return "house.fill"
        case .commutingHome: return "airplane"
        case .drivingHome: return "car.fill"
        case .drivingToWork: return "car.fill"
        case .inFlight: return AirlineBranding.symbolName(for: currentAirlineCode)
        case .turn: return "arrow.triangle.2.circlepath"
        case .layover: return "bed.double.fill"
        case .reserve: return "clock.badge.questionmark"
        case .hotStandby: return "bolt.fill"
        case .training: return eventIconOverride() ?? "book.fill"
        case .base: return "building.2.fill"
        case .elsewhere: return "mappin.and.ellipse"
        case .unknown: return "circle.fill"
        }
    }

    private var statusColor: Color {
        switch status.displayStatus {
        case .home: return .green
        case .commutingHome: return .blue
        case .drivingHome: return .green
        case .drivingToWork: return .blue
        case .inFlight: return status.hasFlightDelay ? (status.isEarlyDeparture ? .green : .orange) : AirlineBranding.color(for: currentAirlineCode, colorScheme: colorScheme)
        case .turn: return status.hasFlightDelay ? (status.isEarlyDeparture ? .green : .orange) : .orange
        case .layover: return status.hasFlightDelay ? (status.isEarlyDeparture ? .green : .orange) : .purple
        case .reserve: return .red
        case .hotStandby: return .orange
        case .training: return .purple
        case .base: return .purple
        case .elsewhere: return .secondary
        case .unknown: return .gray
        }
    }
}
