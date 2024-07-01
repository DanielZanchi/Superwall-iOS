//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/05/2022.
//

import UIKit
import Combine

protocol SessionEventsDelegate: AnyObject {
  var triggerSession: TriggerSessionManager { get }

  func enqueue(_ triggerSession: TriggerSession) async
  func enqueue(_ triggerSessions: [TriggerSession]) async
  func enqueue(_ transaction: StoreTransaction) async
}

class SessionEventsManager {
  /// The trigger session manager.
  lazy var triggerSession = factory.makeTriggerSessionManager()

  /// A queue of trigger session events that get sent to the server.
  private let queue: SessionEnqueuable

  private var cancellables: [AnyCancellable] = []

  private unowned let network: Network
  private unowned let storage: Storage
  private unowned let configManager: ConfigManager
  private unowned let factory: TriggerSessionManagerFactory

  init(
    queue: SessionEnqueuable,
    storage: Storage,
    network: Network,
    configManager: ConfigManager,
    factory: TriggerSessionManagerFactory
  ) {
    self.queue = queue
    self.storage = storage
    self.network = network
    self.configManager = configManager
    self.factory = factory

    Task {
      await postCachedSessionEvents()
    }
  }

  /// Gets the last 20 cached trigger sessions and transactions from the last time the app was terminated,
  /// sends them back to the server, then clears cache.
  private func postCachedSessionEvents() async {
    guard configManager.config?.featureFlags.enableSessionEvents == true else {
      return
    }
    let cachedTriggerSessions = storage.get(TriggerSessions.self) ?? []
    let cachedTransactions = storage.get(Transactions.self) ?? []

    if cachedTriggerSessions.isEmpty,
      cachedTransactions.isEmpty {
      return
    }

    let sessionEvents = SessionEventsRequest(
      triggerSessions: cachedTriggerSessions,
      transactions: cachedTransactions
    )

    await network.sendSessionEvents(sessionEvents)

    storage.clearCachedSessionEvents()
  }
}

// MARK: - SessionEventsDelegate
extension SessionEventsManager: SessionEventsDelegate {
  func enqueue(_ triggerSession: TriggerSession) async {
    guard configManager.config?.featureFlags.enableSessionEvents == true else {
      return
    }
    await queue.enqueue(triggerSession)
  }

  func enqueue(_ triggerSessions: [TriggerSession]) async {
    guard configManager.config?.featureFlags.enableSessionEvents == true else {
      return
    }
    await queue.enqueue(triggerSessions)
  }

  func enqueue(_ transaction: StoreTransaction) async {
    guard configManager.config?.featureFlags.enableSessionEvents == true else {
      return
    }
    await queue.enqueue(transaction)
  }
}
