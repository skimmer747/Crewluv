//
//  TripMapCameraController.swift
//  CrewLuve
//
//  The trip map's camera (moving map spec §6, Stage 2 spec §6.1, §6.2, base waits and card framing design §4). It
//  frames each new `TripMapCamera` request, keeps the map's margins (where MapKit puts Apple's logo and Legal link) and
//  its framing clear of the facts sheet, the panel or the card's chips, slides the pilot's ground marker into view when
//  a framing leaves it out, and notices when the family moves the map themselves. While the map follows the plane, it
//  glides toward the frame it's handed on every display frame (follow the plane design §4).
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
    /// The request last framed, and the size and layout margins it was framed for.
    private var framedNumber: Int?
    private var framedSize: CGSize = .zero
    private var framedMargins: UIEdgeInsets = .zero
    /// The marker an animated framing keeps in view, slid in once the framing has finished.
    private var pendingKeptInView: CLLocationCoordinate2D?
    /// While the map follows the plane: the frame it glides toward, the frame it's at, and the display link that moves
    /// it, which runs only until it gets there.
    private var followTarget: MKMapRect?
    private var followCurrent: MKMapRect?
    private var displayLink: CADisplayLink?
    private var lastGlide: CFTimeInterval?
    /// While the map follows the plane, new margins are eased in with the glide, from `appliedMargins` to these, so a
    /// banner coming or going slides the map instead of jumping it. Nil when the applied margins are the ones wanted.
    private var marginsTarget: NSDirectionalEdgeInsets?
    /// The frame the map was last asked to show, by a framing or the glide: where a glide starts from. Nil once the
    /// family has moved the map, which it no longer shows.
    private var lastRequested: MKMapRect?

    init(mapView: MKMapView) {
        self.mapView = mapView
        baseMargins = mapView.directionalLayoutMargins
        super.init()
        observeGestures(on: mapView)
    }

    // MARK: - Updates

    /// SwiftUI's latest camera, clearance and kind of map, and the frame to follow the plane to, if it's following.
    /// While it follows, the glide moves the map, and a refit's request is the glide's to make: a pan or pinch stops
    /// it, and recenter starts it again from where the map is.
    func update(camera: TripMapCamera, clearance newClearance: TripMapClearance, respectsSafeArea newRespectsSafeArea: Bool,
                followFrame: MKMapRect?, glides: Bool) {
        clearance = newClearance
        respectsSafeArea = newRespectsSafeArea
        applyMargins(easing: glides && followCurrent != nil && followFrame != nil && !camera.isPositionedByUser)
        if let followFrame, !camera.isPositionedByUser {
            guard let mapView, mapView.bounds.width > 0, mapView.bounds.height > 0 else { return }
            // The map's first framing goes straight there, as every first framing does.
            let isFirstFraming = framedNumber == nil
            framedNumber = camera.framingNumber
            framedSize = mapView.bounds.size
            framedMargins = mapView.layoutMargins
            follow(toward: followFrame, glides: glides && !isFirstFraming)
        } else {
            stopFollowing()
            frameIfNeeded(camera)
        }
    }

    /// The map's size or safe area has changed.
    func layoutDidChange(camera: TripMapCamera) {
        applyMargins()
        if let followCurrent {
            show(followCurrent)
        } else {
            frameIfNeeded(camera)
        }
    }

    // MARK: - Following the plane

    /// Glides toward `target` from where the map is, on every display frame until it gets there, or goes straight to
    /// it with Reduce Motion on, or when it's already as good as there, as live it nearly always is. A frame that's
    /// already shown isn't shown again.
    private func follow(toward target: MKMapRect, glides: Bool) {
        guard let mapView, Self.isFinite(target) else { return }
        pendingKeptInView = nil
        if let followCurrent, displayLink == nil, marginsTarget == nil, MKMapRectEqualToRect(followCurrent, target) { return }
        followTarget = target
        let current = followCurrent ?? lastRequested ?? shownRect(of: mapView)
        guard glides, marginsTarget != nil || !TripMapGlide.isThere(current, at: target) else {
            followCurrent = target
            show(target)
            pauseGlide()
            return
        }
        followCurrent = current
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(glide(_:)))
        // Smooth enough at 60 a second, and no more on a ProMotion screen.
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    /// One display frame of the glide.
    @objc private func glide(_ link: CADisplayLink) {
        guard let target = followTarget, let current = followCurrent else { return stopFollowing() }
        let elapsed = lastGlide.map { link.timestamp - $0 } ?? link.duration
        lastGlide = link.timestamp
        easeMargins(over: elapsed)
        let next = TripMapGlide.step(from: current, toward: target, over: elapsed)
        followCurrent = next
        show(next)
        if MKMapRectEqualToRect(next, target), marginsTarget == nil { pauseGlide() }
    }

    /// One display frame of new margins easing in, by the glide's own share, arriving within half a point.
    private func easeMargins(over elapsed: TimeInterval) {
        guard let mapView, let target = marginsTarget, let applied = appliedMargins else { return }
        let share = 1 - exp(-elapsed / TripMapGlide.timeConstant)
        func eased(_ from: CGFloat, _ to: CGFloat) -> CGFloat {
            abs(to - from) * (1 - share) < 0.5 ? to : from + (to - from) * share
        }
        let next = NSDirectionalEdgeInsets(top: eased(applied.top, target.top), leading: eased(applied.leading, target.leading),
                                           bottom: eased(applied.bottom, target.bottom),
                                           trailing: eased(applied.trailing, target.trailing))
        appliedMargins = next
        mapView.directionalLayoutMargins = next
        if next == target { marginsTarget = nil }
    }

    /// The glide has got there: the link stops until the frame moves on.
    private func pauseGlide() {
        displayLink?.invalidate()
        displayLink = nil
        lastGlide = nil
    }

    /// The map isn't following now: nothing glides, and the next follow starts from where the map is.
    func stopFollowing() {
        pauseGlide()
        followTarget = nil
        followCurrent = nil
        // Margins still easing in go on at once.
        if let marginsTarget {
            appliedMargins = marginsTarget
            mapView?.directionalLayoutMargins = marginsTarget
            self.marginsTarget = nil
        }
    }

    /// Shows `rect` inside the map's margins, as a framing does, at once, and has the drawing and any popup follow,
    /// since MapKit needn't report a move it wasn't asked to animate.
    private func show(_ rect: MKMapRect) {
        lastRequested = rect
        mapView?.setVisibleMapRect(rect, edgePadding: .zero, animated: false)
        onFramedWithoutAnimation?()
    }

    /// Whether every number of `rect` is a real one, so a frame worked out from bad data never reaches MapKit.
    private static func isFinite(_ rect: MKMapRect) -> Bool {
        [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height].allSatisfy(\.isFinite)
    }

    /// What the map shows inside its margins, as a frame: where a glide starts from.
    private func shownRect(of mapView: MKMapView) -> MKMapRect {
        let visible = mapView.visibleMapRect
        let scale = visible.size.width / mapView.bounds.width
        let margins = mapView.layoutMargins
        return MKMapRect(x: visible.origin.x + margins.left * scale, y: visible.origin.y + margins.top * scale,
                         width: visible.size.width - (margins.left + margins.right) * scale,
                         height: visible.size.height - (margins.top + margins.bottom) * scale)
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

    /// UIKit adds the safe area to the margins itself, so only the clearance beyond it goes on. While the map glides
    /// after the plane (`easing`), new margins are eased in by the glide, so the latest event's banner coming at a
    /// takeoff, or going, slides the map instead of jumping it.
    private func applyMargins(easing: Bool = false) {
        guard let mapView else { return }
        if mapView.insetsLayoutMarginsFromSafeArea != respectsSafeArea {
            mapView.insetsLayoutMarginsFromSafeArea = respectsSafeArea
        }
        let extra = clearance.marginsBeyondSafeArea(safeArea, isRightToLeft: isRightToLeft)
        let margins = NSDirectionalEdgeInsets(top: baseMargins.top + extra.top,
                                              leading: baseMargins.leading + extra.leading,
                                              bottom: baseMargins.bottom + extra.bottom,
                                              trailing: baseMargins.trailing + extra.trailing)
        guard margins != (marginsTarget ?? appliedMargins) else { return }
        guard !easing || appliedMargins == nil else {
            marginsTarget = margins
            return
        }
        marginsTarget = nil
        appliedMargins = margins
        mapView.directionalLayoutMargins = margins
    }

    /// Frames the camera's rectangle when it's a new request, or when the map's size or layout margins have changed
    /// and the family hasn't moved the map. The first framing, as the map opens, is never animated.
    ///
    /// MapKit fits the rectangle inside the map's layout margins, which hold the safe area and the sheet or panel
    /// (`applyMargins()`), so it's given no padding of its own. Padding as well counted the panel twice: on Todd's iPad
    /// the trip sat small, far to the right of it.
    private func frameIfNeeded(_ camera: TripMapCamera) {
        guard let mapView, mapView.bounds.width > 0, mapView.bounds.height > 0 else { return }
        let margins = mapView.layoutMargins
        let isNewRequest = camera.framingNumber != framedNumber
        let hasLayoutChanged = mapView.bounds.size != framedSize || margins != framedMargins
        guard isNewRequest || (hasLayoutChanged && !camera.isPositionedByUser) else { return }
        let isAnimated = isNewRequest && framedNumber != nil && camera.isAnimated
        framedNumber = camera.framingNumber
        framedSize = mapView.bounds.size
        framedMargins = margins
        // Each framing replaces any slide an earlier one left waiting: MapKit may never report an animation to a
        // rectangle already shown.
        pendingKeptInView = nil
        guard let rect = camera.rect else { return }
        lastRequested = rect
        mapView.setVisibleMapRect(rect, edgePadding: .zero, animated: isAnimated)
        if isAnimated {
            pendingKeptInView = camera.keptInView
        } else {
            slide(toKeep: camera.keptInView, animated: false)
            onFramedWithoutAnimation?()
        }
    }

    // MARK: - Keeping the pilot in view

    /// MapKit has finished moving the map: an animated framing's marker slides in now (base waits and card framing
    /// design §4.2).
    func regionDidChange() {
        guard let coordinate = pendingKeptInView else { return }
        pendingKeptInView = nil
        slide(toKeep: coordinate, animated: true)
    }

    /// Slides the map the least distance that brings the pilot's marker, with room around it, inside the map's
    /// margins: on the card between its chips, on the full-screen map clear of the sheet or panel. It never zooms.
    private func slide(toKeep coordinate: CLLocationCoordinate2D?, animated: Bool) {
        guard let mapView, let coordinate else { return }
        let size = CGSize(width: TripMapMarkers.Pilot.diameter, height: TripMapMarkers.Pilot.diameter)
        let marker = TripMapSlide.markerFrame(standingOn: mapView.convert(coordinate, toPointTo: mapView), size: size)
        let offset = TripMapSlide.offset(moving: marker, inside: mapView.bounds.inset(by: mapView.layoutMargins))
        guard offset != .zero else { return }
        // The marker moves by `offset` when the point that far the other way from the middle becomes the middle.
        let middle = CGPoint(x: mapView.bounds.midX - offset.dx, y: mapView.bounds.midY - offset.dy)
        mapView.setCenter(mapView.convert(middle, toCoordinateFrom: mapView), animated: animated)
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
        // The family's move wins over a slide still to come, and over the glide.
        pendingKeptInView = nil
        lastRequested = nil
        stopFollowing()
        onUserMoved?()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}
