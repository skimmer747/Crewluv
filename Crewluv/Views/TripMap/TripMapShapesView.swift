//
//  TripMapShapesView.swift
//  CrewLuve
//
//  The trip map's own drawing: the night and the route lines (moving map spec §7.1, §10). Ported from CrewLu's
//  moving map (Duty/Duty/Views/Map/FlightMapShapesView.swift). MapKit keeps the base map and the markers. This view
//  sits just under the markers, takes no touches, and draws what `TripMapShapesController` hands it.
//
//  MapKit's own overlays flash when they're taken off and put on many times a second, so anything on the map that
//  changes over time is drawn here: the same layers are given new outlines, and nothing is swapped.
//

import CoreGraphics
import QuartzCore
import SwiftUI
import UIKit

final class TripMapShapesView: UIView {
    /// Shapes and lines are cut off this far outside the view, so nothing handed to the layers has a corner far
    /// off screen. It's more than half the widest line, so a cut end never shows.
    static let clipMargin: CGFloat = 50

    /// How the lines stack, bottom first: the line being flown on top.
    private static let lineOrder: [RouteSegment.Style] = [.flown, .drive, .upcoming, .unseen, .flying, .seen]

    /// Called when what's drawn must be laid again: the view has changed size.
    var onNeedsRedraw: (() -> Void)?

    /// One for each of the night's sun heights, the shallowest first. They sit under the lines.
    private let nightLayers: [CAShapeLayer]
    /// One for each style of line, above the night.
    private let lineLayers: [RouteSegment.Style: CAShapeLayer]
    private var palette = TripMapPalette.onDarkMap
    private var laidOutSize: CGSize = .zero

    init(nightLayerCount: Int, nightFill: UIColor) {
        nightLayers = (0..<nightLayerCount).map { _ in
            let layer = CAShapeLayer()
            layer.fillColor = nightFill.cgColor
            layer.strokeColor = nil
            return layer
        }
        lineLayers = Dictionary(uniqueKeysWithValues: Self.lineOrder.map { style in
            let layer = CAShapeLayer()
            layer.fillColor = nil
            layer.lineJoin = .round
            return (style, layer)
        })
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        clipsToBounds = true
        isOpaque = false
        backgroundColor = .clear
        accessibilityElementsHidden = true
        for nightLayer in nightLayers { layer.addSublayer(nightLayer) }
        for lineLayer in Self.lineOrder.compactMap({ lineLayers[$0] }) { layer.addSublayer(lineLayer) }
        applyPalette()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: TripMapShapesView, _: UITraitCollection) in
            // System colours differ between light and dark, so the lines' colours are resolved again.
            view.applyPalette()
        }
    }

    /// This view is only ever made in code.
    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != laidOutSize else { return }
        laidOutSize = bounds.size
        onNeedsRedraw?()
    }

    /// Everything is cut off at the edge of this rectangle.
    private var clipRect: CGRect {
        bounds.insetBy(dx: -Self.clipMargin, dy: -Self.clipMargin)
    }

    /// Layers animate a change of path, colour or opacity unless told not to. Here every change is one frame of a
    /// drawing that's already moving, so none of them may.
    private func withoutAnimation(_ changes: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        changes()
        CATransaction.commit()
    }

    // MARK: - The night

    /// Draws the night. `layers` holds one entry for each night layer, and each entry is that layer's closed
    /// shapes as places on the flat map.
    func drawNight(_ layers: [[[FlatMapPoint]]], projection: MapProjection) {
        let rect = clipRect
        withoutAnimation {
            for (index, nightLayer) in nightLayers.enumerated() {
                let path = CGMutablePath()
                if index < layers.count {
                    for shape in layers[index] {
                        for outline in projection.outlines(of: shape, in: rect) {
                            path.addLines(between: outline)
                            path.closeSubpath()
                        }
                    }
                }
                nightLayer.path = path
            }
        }
    }

    // MARK: - The lines

    /// Gives the lines their colours, widths and ends. Their dashes are laid when they're drawn.
    func setPalette(_ newPalette: TripMapPalette) {
        guard newPalette != palette else { return }
        palette = newPalette
        applyPalette()
    }

    /// Draws the route lines, each already laid out in one piece (`TripMapLine`). Dashed and dotted styles are dashed
    /// here, piece by piece, from each line's far end, so a dash stays put on the map while the plane eats into the
    /// line or a pan moves where the line is cut off.
    func drawLines(_ lines: [TripMapLine], projection: MapProjection) {
        let rect = clipRect
        var paths: [RouteSegment.Style: CGMutablePath] = [:]
        for line in lines {
            let path = paths[line.style] ?? CGMutablePath()
            let dash = palette.stroke(for: line.style).dash
            let patternLength = Double(dash.reduce(0, +))
            for piece in projection.linePieces(of: line.points, in: rect) {
                let stretch = CGMutablePath()
                stretch.addLines(between: piece.points)
                if patternLength > 0 {
                    path.addPath(stretch.copy(dashingWithPhase: piece.dashPhase(patternLength: patternLength), lengths: dash))
                } else {
                    path.addPath(stretch)
                }
            }
            paths[line.style] = path
        }
        withoutAnimation {
            for (style, lineLayer) in lineLayers {
                lineLayer.path = paths[style]
            }
        }
    }

    /// Colours are resolved with this view's own traits: a plain `cgColor` would use whatever look happened to be
    /// current when the frame ran.
    private func applyPalette() {
        withoutAnimation {
            for (style, lineLayer) in lineLayers {
                let stroke = palette.stroke(for: style)
                lineLayer.strokeColor = UIColor(palette.color(for: style)).resolvedColor(with: traitCollection).cgColor
                lineLayer.lineWidth = stroke.lineWidth
                lineLayer.lineCap = Self.layerCap(stroke.lineCap)
            }
        }
    }

    private static func layerCap(_ cap: CGLineCap) -> CAShapeLayerLineCap {
        switch cap {
        case .round: .round
        case .square: .square
        case .butt: .butt
        @unknown default: .butt
        }
    }
}
