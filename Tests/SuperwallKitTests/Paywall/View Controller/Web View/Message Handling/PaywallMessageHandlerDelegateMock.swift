//
//  File.swift
//  
//
//  Created by Yusuf Tör on 19/01/2023.
//

import Foundation
@testable import SuperwallKit

final class FakeWebView: SWWebView {
  var willHandleJs = false
  override func evaluateJavaScript(_ javaScriptString: String, completionHandler: (@MainActor (Any?, (any Error)?) -> Void)? = nil) {
    willHandleJs = true
  }
}

final class PaywallMessageHandlerDelegateMock: PaywallMessageHandlerDelegate {
  var eventDidOccur: PaywallWebEvent?
  var didPresentSafariInApp = false
  var didOpenDeepLink = false
  var didPresentSafariExternal = false

  var request: PresentationRequest?

  var paywall: SuperwallKit.Paywall = .stub()

  var info: SuperwallKit.PaywallInfo

  var webView: SuperwallKit.SWWebView

  var loadingState: SuperwallKit.PaywallLoadingState = .loadingURL

  var isActive = false

  init(
    paywallInfo: SuperwallKit.PaywallInfo,
    webView: FakeWebView
  ) {
    self.info = paywallInfo
    self.webView = webView
  }

  func eventDidOccur(_ paywallWebEvent: SuperwallKit.PaywallWebEvent) {
    eventDidOccur = paywallWebEvent
  }

  func openDeepLink(_ url: URL) {
    didOpenDeepLink = true
  }

  func presentSafariInApp(_ url: URL) {
    didPresentSafariInApp = true
  }

  func presentSafariExternal(_ url: URL) {
    didPresentSafariExternal = true
  }
}
