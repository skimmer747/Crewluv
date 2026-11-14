//
//  TripMapCameraController.swift
//  CrewLuve
//
//  The trip map's camera (moving map spec §6, Stage 2 spec §6.1, §6.2). It frames each new `TripMapCamera` request,
//  keeps the map's margins (where MapKit puts Apple's logo and Legal link) and its framing clear of the facts sheet or
//  panel, and notices when the family moves the map themselves.
//

import MapKit
import UIKit

final class TripMapCameraController: NSObject, UIGestureRecognizerDelegate {
    /// The family has panned, pinched or double-tapped the map.
    var onUserMoved: (() -> Void)?
    /// The camera was framed without an animation, which MapKit needn't report.
    var onFramedWithoutAnimation: (() -> Void)?

    private weak var mapView: MKMapView?
    /// The map's own margins, read before it's on screen, so they hold no safe area.
    private let baseMargins: NSDirectionalEdgeInsets
    private var clearance = TripMapClearance.none
    /// The full-screen map keeps clear of the screen's safe area. The card's map ignores it, so a card scrolled under
    /// the status bar keeps its camera and its logo where they are.
    private var respectsSafeArea = false
    private var appliedMargins: NSDirectionalEdgeInsets?
    /// The request last framed, and the size and padding it was framed for.
    private var framedNumber: Int?
    private var framedSize: CGSize = .zero
    private var framedPadding: UIEdgeInsets = .zero

    init(mapView: MKMapView) {
        self.mapView = mapView
        baseMargins = mapView.directionalLayoutMargins
        super.init()
        observeGestures(on: mapView)
    }

    // MARK: - Updates

    /// SwiftUI's latest camera, clearance and kind of map.
    func update(camera: TripMapCamera, clearance newClearance: TripMapClearance, respectsSafeArea newRespectsSafeArea: Bool) {
        clearance = newClearance
        respectsSafeArea = newRespectsSafeArea
        applyMargins()
        frameIfNeeded(camera)
    }

    /// The map's size or safe area has changed.
    func layoutDidChange(camera: TripMapCamera) {
        applyMargins()
        frameIfNeeded(camera)
    }

    // MARK: - Margins and framing

    /// Read from the view holding the map, which it fills: the map's own copy can lag a layout behind as the device
    /// turns.
    private var safeArea: UIEdgeInsets {
        guard respectsSafeArea, let mapView else { return .zero }
        return (mapView.superview ?? mapView).safeAreaInsets
    }

    private var isRightToLeft: Bool {
        mapView?.effectiveUserInterfaceLayoutDirection == .rightToLeft
    }

    /// UIKit adds the safe area to the margins itself, so only the clearance beyond it goes on.
    private func applyMargins() {
        guard let mapView else { return }
        if mapView.insetsLayoutMarginsFromSafeArea != respectsSafeArea {
            mapView.insetsLayoutMarginsFromSafeArea = respectsSafeArea
        }
        let extra = clearance.marginsBeyondSafeArea(safeArea, isRightToLeft: isRightToLeft)
        let margins = NSDirectionalEdgeInsets(top: baseMargins.top + extra.top,
                                              leading: baseMargins.leading + extra.leading,
                                              bottom: baseMargins.bottom + extra.bottom,
                                              trailing: baseMargins.trailing + extra.trailing)
        guard margins != appliedMargins else { return }
        appliedMargins = margins
        mapView.directionalLayoutMargins = margins
    }

    /// Frames the camera's rectangle when it's a new request, or when the map's size, safe area or clearance has
    /// changed and the family hasn't moved the map. The first framing, as the map opens, is never animated.
    private func frameIfNeeded(_ camera: TripMapCamera) {
        guard let mapView, mapView.bounds.width > 0, mapView.bounds.height > 0 else { return }
        let padding = clearance.framingPadding(safeArea: safeArea, isRightToLeft: isRightToLeft)
        let isNewRequest = camera.framingNumber != framedNumber
        let hasLayoutChanged = mapView.bounds.size != framedSize || padding != framedPadding
        guard isNewRequest || (hasLayoutChanged && !camera.isPositionedByUser) else { return }
        let isAnimated = isNewRequest && framedNumber != nil && camera.isAnimated
        framedNumber = camera.framingNumber
        framedSize = mapView.bounds.size
        framedPadding = padding
        guard let rect = camera.rect else { return }
        mapView.setVisibleMapRect(rect, edgePadding: padding, animated: isAnimated)
        if !isAnimated { onFramedWithoutAnimation?() }
    }

    // MARK: - The family moving the map

    /// Watches for the map's own gestures without taking part in them: each recognizer works alongside MapKit's and
    /// never cancels or holds back a touch.
    private func observeGestures(on mapView: MKMapView) {
        let pan = UIPanGestureRecognizer()
        // A trackpad's two-finger scroll pans the map on iPad too.
        pan.allowedScrollTypesMask = .all
        let doubleTap = UITapGestureRecognizer()
        doubleTap.numberOfTapsRequired = 2
        let twoFingerTap = UITapGestureRecognizer()
        twoFingerTap.numberOfTouchesRequired = 2
        for recognizer in [pan, UIPinchGestureRecognizer(), doubleTap, twoFingerTap] {
            recognizer.addTarget(self, action: #selector(mapGestureChanged(_:)))
            recognizer.delegate = self
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            mapView.addGestureRecognizer(recognizer)
        }
    }

    /// A pan or pinch says so as it begins, a tap once it's recognized.
    @objc private func mapGestureChanged(_ recognizer: UIGestureRecognizer) {
        guard recognizer.state == .began || recognizer.state == .ended else { return }
        onUserMoved?()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}
