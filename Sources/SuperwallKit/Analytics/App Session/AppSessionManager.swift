//
//  File.swift
//  
//
//  Created by Yusuf Tör on 04/05/2022.
//

import UIKit
import Combine

protocol AppManagerDelegate: AnyObject {
  func didUpdateAppSession(_ appSession: AppSession) async
}

class AppSessionManager {
  var appSessionTimeout: Milliseconds?

  private(set) var appSession = AppSession() {
    didSet {
      Task {
        await delegate.didUpdateAppSession(appSession)
      }
    }
  }
  private var lastAppClose: Date?
  private var didTrackAppLaunch = false
  private var cancellable: AnyCancellable?

  private unowned let configManager: ConfigManager
  private unowned let storage: Storage
  private unowned let delegate: AppManagerDelegate & DeviceHelperFactory & UserAttributesEventFactory

  init(
    configManager: ConfigManager,
    identityManager: IdentityManager,
    storage: Storage,
    delegate: AppManagerDelegate & DeviceHelperFactory & UserAttributesEventFactory
  ) {
    self.configManager = configManager
    self.storage = storage
    self.delegate = delegate
    Task {
      await addActiveStateObservers()
    }
    listenForAppSessionTimeout()
  }

  // MARK: - Listeners
  @MainActor
  private func addActiveStateObservers() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationWillResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationWillTerminate),
      name: UIApplication.willTerminateNotification,
      object: nil
    )
  }

  func listenForAppSessionTimeout() {
    cancellable = configManager.configState
      .compactMap { $0.getConfig() }
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { [weak self] config in
          guard let self = self else {
            return
          }
          self.appSessionTimeout = config.appSessionTimeout

          // Account for the fact that dev may have delayed the init of Superwall
          // such that applicationDidBecomeActive() doesn't activate.
          if !self.didTrackAppLaunch {
            Task {
              await self.sessionCouldRefresh()
            }
          }
        }
      )
  }

  @objc private func applicationWillResignActive() {
    storage.recordFirstSessionTracked()
    Task {
      await Superwall.shared.track(InternalSuperwallEvent.AppClose())
    }
    lastAppClose = Date()
    appSession.endAt = Date()
  }

  @objc private func applicationWillTerminate() {
    appSession.endAt = Date()
  }

  @objc private func applicationDidBecomeActive() {
    Task {
      await Superwall.shared.track(InternalSuperwallEvent.AppOpen())
      await sessionCouldRefresh()
    }
  }

  // MARK: - Logic

  /// Tries to track a new app session, then app launch, then first seen.
  ///
  /// Note: Order is important here because we need to check if it's an app launch
  /// when deciding whether to track device attributes.
  private func sessionCouldRefresh() async {
    await detectNewSession()
    await trackAppLaunch()
    storage.recordFirstSeenTracked()
  }

  private func detectNewSession() async {
    let didStartNewSession = AppSessionLogic.didStartNewSession(
      lastAppClose,
      withSessionTimeout: appSessionTimeout
    )

    if didStartNewSession {
      appSession = AppSession()

      let deviceAttributes = await delegate.makeSessionDeviceAttributes()
      let userAttributes = delegate.makeUserAttributesEvent()

      await withTaskGroup(of: Void.self) { [weak self] group in
        guard let self = self else {
          return
        }
        if self.didTrackAppLaunch {
          group.addTask {
            await Superwall.shared.track(
              InternalSuperwallEvent.DeviceAttributes(deviceAttributes: deviceAttributes)
            )
          }
          group.addTask {
            if let config = self.configManager.config {
              await Superwall.shared.track(InternalSuperwallEvent.SessionStart(configTimestamp: config.ts))
            }
          }
        }
        group.addTask {
          await Superwall.shared.track(userAttributes)
        }
      }
    } else {
      appSession.endAt = nil
    }
  }

  private func trackAppLaunch() async {
    if didTrackAppLaunch {
      return
    }
    await Superwall.shared.track(InternalSuperwallEvent.AppLaunch())
    didTrackAppLaunch = true
  }
}
