//
//  TripMapAnnotationView.swift
//  CrewLuve
//
//  The view MapKit shows for a `TripMapAnnotation` (moving map spec §5.1, §7.2): the marker's SwiftUI view,
//  `TripMapMarkerView`, hosted through a `UIHostingConfiguration`, so the markers are the views SwiftUI's map drew.
//  MapKit keeps these views above the app's own drawing of the night, so they stay bright.
//

import MapKit
import SwiftUI
import UIKit

final class TripMapAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "TripMapAnnotationView"

    /// The marker's SwiftUI view: made on first use, and given each new marker after that.
    private var hostedView: (any UIView & UIContentView)?
    /// The `TripMapMarker.sizeKey` the view was last measured for.
    private var measuredSizeKey: String?

    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        canShowCallout = false
        // A marker is never selected, so a tap can't lift a car above the plane. Touches go on to the map.
        isEnabled = false
        // Every marker always shows: MapKit never hides one for crowding another.
        displayPriority = .required
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: TripMapAnnotationView, _: UITraitCollection) in
            // An airport's code grows and shrinks with the text size.
            view.measuredSizeKey = nil
            view.refresh()
        }
        refresh()
    }

    /// This view is only ever made in code.
    required init?(coder: NSCoder) {
        return nil
    }

    override var annotation: (any MKAnnotation)? {
        didSet { refresh() }
    }

    /// Shows the annotation's marker as it is now. MapKit triggers this through `annotation`. The coordinator calls
    /// it after changing a marker in place, such as the plane's angle.
    func refresh() {
        guard let marker = (annotation as? TripMapAnnotation)?.marker else { return }
        let hosted = hostedView(showing: marker)
        zPriority = Self.zPriority(of: marker)
        accessibilityLabel = Self.accessibilityLabel(of: marker)
        isAccessibilityElement = accessibilityLabel != nil
        guard marker.sizeKey != measuredSizeKey else { return }
        measuredSizeKey = marker.sizeKey
        let size = hosted.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        hosted.frame = CGRect(origin: .zero, size: size)
        bounds.size = size
        centerOffset = Self.centerOffset(of: marker, size: size)
    }

    /// The hosted view, showing `marker`. Its configuration is replaced rather than the view, which keeps the SwiftUI
    /// view's state, such as where the plane is in its turn.
    private func hostedView(showing marker: TripMapMarker) -> any UIView & UIContentView {
        let configuration = UIHostingConfiguration { TripMapMarkerView(marker: marker) }
            .margins(.all, 0)
            .minSize(width: 0, height: 0)
        if let hostedView {
            hostedView.configuration = configuration
            return hostedView
        }
        let hosted = configuration.makeContentView()
        hosted.backgroundColor = .clear
        hosted.isUserInteractionEnabled = false
        addSubview(hosted)
        hostedView = hosted
        return hosted
    }

    // MARK: - Placing each marker

    /// Where the view's centre sits from its coordinate. The airport's dot sits on the airport with its code below;
    /// the heart stands on its place, as SwiftUI's bottom anchor had it.
    private static func centerOffset(of marker: TripMapMarker, size: CGSize) -> CGPoint {
        switch marker {
        case .airport: CGPoint(x: 0, y: size.height / 2 - TripMapMarkers.Airport.dotDiameter / 2)
        case .heart: CGPoint(x: 0, y: -size.height / 2)
        case .car, .plane: .zero
        }
    }

    /// The plane on top, then the heart, the cars and the airports.
    private static func zPriority(of marker: TripMapMarker) -> MKAnnotationViewZPriority {
        switch marker {
        case .plane: .max
        case .heart: MKAnnotationViewZPriority(rawValue: 900)
        case .car: MKAnnotationViewZPriority(rawValue: 700)
        case .airport: .defaultUnselected
        }
    }

    /// VoiceOver reads each airport's code, as SwiftUI's map read its titles. The card's sentence and the facts
    /// describe the rest.
    private static func accessibilityLabel(of marker: TripMapMarker) -> String? {
        guard case .airport(let code, _) = marker else { return nil }
        return code
    }
}
