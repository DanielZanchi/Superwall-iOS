//
//  File.swift
//  
//
//  Created by Yusuf Tör on 16/09/2022.
//
// Taken from: https://www.swiftbysundell.com/articles/retrying-an-async-swift-task/

import Foundation

extension Task where Failure == Error {
  @discardableResult
  static func retrying(
    priority: TaskPriority? = nil,
    maxRetryCount: Int,
    retryInterval: Seconds? = nil,
    isRetryingCallback: ((Int) -> Void)?,
    operation: @Sendable @escaping () async throws -> Success
  ) -> Task {
    Task(priority: priority) {
      for attempt in 0..<maxRetryCount {
        do {
          return try await operation()
        } catch {
          isRetryingCallback?(attempt + 1)

          if let retryInterval = retryInterval {
            let oneSecond = TimeInterval(1_000_000_000)
            let nanoseconds = UInt64(oneSecond * retryInterval)
            try await Task<Never, Never>.sleep(nanoseconds: nanoseconds)
          } else if let delay = TaskRetryLogic.delay(
            forAttempt: attempt,
            maxRetries: maxRetryCount
          ) {
            try await Task<Never, Never>.sleep(nanoseconds: delay)
          }

          continue
        }
      }

      try Task<Never, Never>.checkCancellation()
      return try await operation()
    }
  }
}
