//
//  TripMapContainerView.swift
//  CrewLuve
//
//  Holds the trip map's `MKMapView` and says when its size or safe area changes, so the camera can frame the trip
//  for the new shape. MapKit's view isn't meant to be subclassed, so this is the view SwiftUI holds.
//

import MapKit
import UIKit

final class TripMapContainerView: UIView {
    let mapView = MKMapView()
    /// Called when the map's size or safe area changes, its first layout included.
    var onLayoutChange: (() -> Void)?
    private var laidOutSize: CGSize = .zero
    private var laidOutSafeArea: UIEdgeInsets = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(mapView)
    }

    /// This view is only ever made in code.
    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        mapView.frame = bounds
        guard bounds.size != laidOutSize || safeAreaInsets != laidOutSafeArea else { return }
        laidOutSize = bounds.size
        laidOutSafeArea = safeAreaInsets
        mapView.layoutIfNeeded()
        onLayoutChange?()
    }

    /// Answered in the next layout, once the map has its new frame, rather than with the old one mid-rotation.
    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        setNeedsLayout()
    }
}
