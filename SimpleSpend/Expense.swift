//
//  Expense.swift
//  
//
//  Created by SwiftDataModel on 2026-02-19.
//

import Foundation
import SwiftData

@Model
final class Expense: Identifiable {
    var id: UUID
    var title: String
    var amount: Double
    var category: String
    var date: Date

    init(title: String, amount: Double, category: String, date: Date = Date()) {
        self.id = UUID()
        self.title = title
        self.amount = amount
        self.category = category
        self.date = date
    }
}
