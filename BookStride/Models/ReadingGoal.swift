//
//  ReadingGoal.swift
//  BookStride
//
//  SwiftData persistent model representing configured reading goals.
//

import Foundation
import SwiftData

@Model
public final class ReadingGoal {
    public var id: UUID = UUID()
    public var dailyMinutes: Int = 30
    public var dailyPages: Int?
    public var yearlyBookTarget: Int?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    
    public init(
        id: UUID = UUID(),
        dailyMinutes: Int = 30,
        dailyPages: Int? = nil,
        yearlyBookTarget: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.dailyMinutes = dailyMinutes
        self.dailyPages = dailyPages
        self.yearlyBookTarget = yearlyBookTarget
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    public var dailyGoalSeconds: Int {
        dailyMinutes * 60
    }
}

