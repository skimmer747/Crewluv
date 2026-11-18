//
//  TripMapPopupController.swift
//  CrewLuve
//
//  Shows a plane's popup on the full-screen map (which plane design §3): over the real plane or the ghost the family
//  tapped, laid again wherever the plane is at each update and all through a pan or pinch, with the words of the
//  moment. It sits over the map in its container and takes no touches, so a tap goes on to the map, which closes the
//  popup or moves it to the other plane.
//

import MapKit
import SwiftUI
import UIKit

final class TripMapPopupController {
    private weak var container: UIView?
    private weak var mapView: MKMapView?
    /// Hosts the popup's SwiftUI view: made the first time a popup opens, and hidden while none is open.
    private var host: UIHostingController<PlanePopup>?
    /// Where the plane is that the open popup is over. Nil while none is open.
    private var coordinate: CLLocationCoordinate2D?
    /// The popup's size as last measured: a pan lays it again up to 60 times a second.
    private var measurement: Measurement?

    /// How far down from the map's top edge the full-screen map's own controls reach: the popup stays below them.
    var controlsHeight: CGFloat = 0

    private struct Measurement {
        let words: PlanePopupWords
        let width: CGFloat
        let textSize: UIContentSizeCategory
        let size: CGSize
    }

    init(container: UIView, mapView: MKMapView) {
        self.container = container
        self.mapView = mapView
    }

    func tearDown() {
        host?.view.removeFromSuperview()
        host = nil
    }

    /// Shows `words` over the plane at `coordinate`. Their view is given new words only when they change.
    func show(_ words: PlanePopupWords, at coordinate: CLLocationCoordinate2D) {
        let host = host(showing: words)
        self.coordinate = coordinate
        host.view.isHidden = false
        layOut(host)
    }

    func hide() {
        coordinate = nil
        host?.view.isHidden = true
    }

    /// Lays the open popup over its plane again, where the map now shows it: through a pan, a pinch, or a new size.
    func reposition() {
        guard let host, coordinate != nil else { return }
        layOut(host)
    }

    // MARK: - Private

    private func host(showing words: PlanePopupWords) -> UIHostingController<PlanePopup> {
        if let host {
            if host.rootView.words != words {
                host.rootView = PlanePopup(words: words)
            }
            return host
        }
        let host = UIHostingController(rootView: PlanePopup(words: words))
        // Laid in the container's own space, which has no safe area of its own to add.
        host.safeAreaRegions = []
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false
        container?.addSubview(host.view)
        self.host = host
        return host
    }

    /// Lays the popup over the plane inside the map's margins, which keep clear of the sheet or panel, and below the
    /// top bar, the banner and the key.
    private func layOut(_ host: UIHostingController<PlanePopup>) {
        guard let container, let mapView, let coordinate else { return }
        let margins = mapView.layoutMargins
        let area = mapView.frame.inset(by: UIEdgeInsets(top: max(margins.top, controlsHeight), left: margins.left,
                                                        bottom: margins.bottom, right: margins.right))
        let plane = mapView.convert(coordinate, toPointTo: container)
        host.view.frame = PlanePopupPlacement.frame(of: size(of: host, inside: area.width, for: container.traitCollection),
                                                    over: plane, inside: area)
    }

    /// The popup's size, no wider than its widest at this text size, or than `width`. Measured again only when its
    /// words, the width or the text size change.
    private func size(of host: UIHostingController<PlanePopup>, inside width: CGFloat, for traits: UITraitCollection) -> CGSize {
        let widest = UIFontMetrics(forTextStyle: .footnote).scaledValue(for: PlanePopup.widest, compatibleWith: traits)
        let proposed = min(widest, width)
        let words = host.rootView.words
        if let measurement, measurement.words == words, measurement.width == proposed,
           measurement.textSize == traits.preferredContentSizeCategory {
            return measurement.size
        }
        let size = host.sizeThatFits(in: CGSize(width: proposed, height: .greatestFiniteMagnitude))
        measurement = Measurement(words: words, width: proposed, textSize: traits.preferredContentSizeCategory, size: size)
        return size
    }
}
