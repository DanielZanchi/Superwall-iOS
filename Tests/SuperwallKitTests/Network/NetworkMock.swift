//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/05/2022.
//

import UIKit
import Combine
@testable import SuperwallKit

final class NetworkMock: Network {
  var sentSessionEvents: SessionEventsRequest?
  var getConfigCalled = false
  var assignmentsConfirmed = false
  var assignments: [Assignment] = []
  var configReturnValue: Result<Config, Error> = .success(.stub())

  override func sendSessionEvents(_ session: SessionEventsRequest) async {
    sentSessionEvents = session
  }

  @MainActor
  override func getConfig(
    injectedApplicationStatePublisher: (AnyPublisher<UIApplication.State, Never>)? = nil,
    isRetryingCallback: ((Int) -> Void)? = nil
  ) async throws -> Config {
    getConfigCalled = true

    switch configReturnValue {
    case .success(let success):
      return success
    case .failure(let failure):
      throw failure
    }
  }

  override func confirmAssignments(_ confirmableAssignments: AssignmentPostback) async {
    assignmentsConfirmed = true
  }

  override func getAssignments() async throws -> [Assignment] {
    return assignments
  }
}
