//
//  PulseTicket.swift
//  Pulse
//
//  Created by Camilo Montero on 2026-02-05.
//

import Foundation


struct PulseTicket: Identifiable, Codable {
    let id: UUID
    let eventID: UUID
    let userID: UUID
    let purchaseDate: Date
    var isScanned: Bool
}
