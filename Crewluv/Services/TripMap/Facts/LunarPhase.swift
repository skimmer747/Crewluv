//
//  LunarPhase.swift
//  CrewLuve
//
//  The moon's eight phases, in order from new moon, as the website's moonPhase names them (Stage 2 spec §4.5).
//

nonisolated enum LunarPhase: Int, CaseIterable, Sendable {
    case new, waxingCrescent, firstQuarter, waxingGibbous, full, waningGibbous, lastQuarter, waningCrescent
}
