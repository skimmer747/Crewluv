//
//  MapProjection+Lines.swift
//  CrewLuve
//
//  Route lines on screen (moving map spec §7.1, §10): each copy of the world's pieces, cut off at the edge of the
//  view, ported from CrewLu's FlatMapFit. Added for Crewluve's dashed and dotted lines, which CrewLu's solid ones
//  don't need: how far along its whole line each piece starts, so a dash can be laid from the line's far end and
//  stays put on the map when the near end moves.
//

import CoreGraphics
import Foundation

nonisolated extension MapProjection {

    /// One piece of a line on screen, inside the view.
    nonisolated struct LinePiece: Equatable {
        let points: [CGPoint]
        /// How far along the whole line, uncut and on screen, `points.first` is, in points.
        let startDistance: Double
        /// The whole line's length on screen, uncut, in points.
        let lineLength: Double

        /// The phase to dash this piece with, so the pattern is laid from the line's far end. A dash then stays put
        /// on the map while the near end moves, as the plane eats into the line still to fly, or is cut off in a new
        /// place, as the map pans. `patternLength` is the pattern's dashes and gaps added up.
        func dashPhase(patternLength: Double) -> CGFloat {
            guard patternLength > 0, startDistance.isFinite, lineLength.isFinite else { return 0 }
            let phase = (startDistance - lineLength).truncatingRemainder(dividingBy: patternLength)
            return CGFloat(phase < 0 ? phase + patternLength : phase)
        }
    }

    /// A line on the map as the pieces to draw on screen: for each copy of the world near `rect`, the parts of
    /// the line inside `rect`. `line` must already be laid out in one piece (`unwrapped`).
    func pieces(of line: [FlatMapPoint], in rect: CGRect) -> [[CGPoint]] {
        linePieces(of: line, in: rect).map(\.points)
    }

    /// `pieces(of:in:)`, with how far along the line each piece starts.
    func linePieces(of line: [FlatMapPoint], in rect: CGRect) -> [LinePiece] {
        guard line.count >= 2 else { return [] }
        var pieces: [LinePiece] = []
        for copy in copies(touching: rect, margin: 1) {
            pieces += Self.clippedPieces(line: line.map { screenPoint(for: $0, copy: copy) }, to: rect)
        }
        return pieces
    }

    /// The parts of a line that lie inside `rect`, as separate pieces, in the line's own order.
    static func clipped(line: [CGPoint], to rect: CGRect) -> [[CGPoint]] {
        clippedPieces(line: line, to: rect).map(\.points)
    }

    /// `clipped(line:to:)`, with how far along the line each piece starts. Each straight stretch is cut on its own,
    /// and stretches that still share an end are joined up again.
    static func clippedPieces(line: [CGPoint], to rect: CGRect) -> [LinePiece] {
        let lineLength = zip(line, line.dropFirst()).reduce(0.0) { $0 + length(from: $1.0, to: $1.1) }
        var pieces: [LinePiece] = []
        var piece: [CGPoint] = []
        var pieceStart = 0.0
        // How far along the line the stretch being cut starts.
        var travelled = 0.0
        func finishPiece() {
            if !piece.isEmpty {
                pieces.append(LinePiece(points: piece, startDistance: pieceStart, lineLength: lineLength))
            }
            piece = []
        }
        for index in line.indices.dropFirst() {
            let a = line[index - 1]
            let b = line[index]
            defer { travelled += length(from: a, to: b) }
            guard let part = clipped(from: a, to: b, in: rect) else {
                finishPiece()
                continue
            }
            if let last = piece.last, last == part.from {
                piece.append(part.to)
            } else {
                finishPiece()
                piece = [part.from, part.to]
                pieceStart = travelled + length(from: a, to: part.from)
            }
        }
        finishPiece()
        return pieces
    }

    /// The part of one straight stretch that lies inside `rect`, or nil when none of it does. An end that is
    /// inside comes back exactly as given, so stretches that share an end can be joined up again.
    private static func clipped(from a: CGPoint, to b: CGPoint, in rect: CGRect) -> (from: CGPoint, to: CGPoint)? {
        let ax = Double(a.x), ay = Double(a.y)
        let dx = Double(b.x) - ax, dy = Double(b.y) - ay
        // `t` runs from 0 at `a` to 1 at `b`. Each side of the rectangle keeps the part where p * t <= q.
        var t0 = 0.0, t1 = 1.0
        let sides = [(-dx, ax - Double(rect.minX)), (dx, Double(rect.maxX) - ax),
                     (-dy, ay - Double(rect.minY)), (dy, Double(rect.maxY) - ay)]
        for (p, q) in sides {
            if p == 0 {
                if q < 0 { return nil }
                continue
            }
            let t = q / p
            if p < 0 {
                if t > t1 { return nil }
                t0 = max(t0, t)
            } else {
                if t < t0 { return nil }
                t1 = min(t1, t)
            }
        }
        let from = t0 <= 0 ? a : CGPoint(x: ax + t0 * dx, y: ay + t0 * dy)
        let to = t1 >= 1 ? b : CGPoint(x: ax + t1 * dx, y: ay + t1 * dy)
        return (from, to)
    }

    private static func length(from a: CGPoint, to b: CGPoint) -> Double {
        hypot(Double(b.x - a.x), Double(b.y - a.y))
    }
}
