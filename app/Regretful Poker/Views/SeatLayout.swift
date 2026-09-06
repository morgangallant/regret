//
//  SeatLayout.swift
//  Regretful Poker
//
//  Works out where each seat sits around the oval.
//
//  The person playing is always pinned to bottom centre, and the remaining
//  seats are spread evenly across the arc above them. A wedge at the bottom is
//  left clear so no opponent ever lands behind the action bar or on top of the
//  hero's own cards.
//

import CoreGraphics
import Foundation

struct SeatLayout {
    var playerCount: Int
    /// The seat the local person occupies.
    var heroSeat: Int

    /// Half-width of the clear wedge at the bottom of the table, in radians.
    private static let heroWedge = 52.0 * .pi / 180.0

    /// Seats ordered by their distance clockwise from the hero.
    private func offset(of seat: Int) -> Int {
        guard playerCount > 0 else { return 0 }
        return ((seat - heroSeat) % playerCount + playerCount) % playerCount
    }

    /// Angle around the oval, measured from bottom centre. Increasing angles
    /// travel up the right-hand side, across the top, and down the left.
    func angle(for seat: Int) -> Double {
        let offset = offset(of: seat)
        if offset == 0 { return 0 }

        let opponents = playerCount - 1
        // Heads up: park the single opponent directly opposite.
        if opponents <= 1 { return .pi }

        let span = 2 * .pi - 2 * Self.heroWedge
        return Self.heroWedge
            + span * Double(offset - 1) / Double(opponents - 1)
    }

    /// Position in unit space, where (0.5, 0.5) is the middle of the table.
    ///
    /// - Parameters:
    ///   - radiusX: horizontal radius as a fraction of the table's width.
    ///   - radiusY: vertical radius as a fraction of the table's height.
    func unitPoint(for seat: Int, radiusX: Double, radiusY: Double) -> CGPoint {
        let theta = angle(for: seat)
        return CGPoint(x: 0.5 + radiusX * sin(theta),
                       y: 0.5 + radiusY * cos(theta))
    }

    /// Position in points inside a table of the given size.
    func point(for seat: Int, in size: CGSize,
               radiusX: Double, radiusY: Double) -> CGPoint {
        let unit = unitPoint(for: seat, radiusX: radiusX, radiusY: radiusY)
        return CGPoint(x: unit.x * size.width, y: unit.y * size.height)
    }

    func isHero(_ seat: Int) -> Bool { seat == heroSeat }
}
