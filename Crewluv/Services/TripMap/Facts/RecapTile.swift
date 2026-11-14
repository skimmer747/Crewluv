//
//  RecapTile.swift
//  CrewLuve
//
//  One number on the recap card (Stage 2 spec §6.5): "2 cities", "14,819 miles".
//

nonisolated struct RecapTile: Identifiable, Equatable, Sendable {
    let value: String
    let label: String

    var id: String { label }
}
