//
//  AppDelegate.swift
//  SuperwallUIKitExample
//
//  Created by Yusuf Tör on 05/04/2022.
//

import UIKit
import SuperwallKit
import RevenueCat

@main // You can ignore the main thread error here ->
final class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    #warning("Replace these API keys with your own.")

    // MARK: Step 1 - Create your Purchase Controller
    /// Create an `RCPurchaseController()` wherever Superwall and RevenueCat are being initialized.
    let purchaseController = RCPurchaseController()

    // MARK: Step 2 - Configure Superwall
    /// Always configure Superwall first. Pass in the `purchaseController` you just created.
    Superwall.configure(
      apiKey: "pk_e6bd9bd73182afb33e95ffdf997b9df74a45e1b5b46ed9c9",
      purchaseController: purchaseController
    )

    // MARK: Step 3 – Configure RevenueCat
    /// Always configure RevenueCat after Superwall
    Purchases.configure(with:
      .builder(withAPIKey: "appl_XmYQBWbTAFiwLeWrBJOeeJJtTql")
      .with(storeKitVersion: .storeKit1)
      .build()
    )

    // MARK: Step 4 – Sync Entitlements
    /// Keep Superwall's entitlements up-to-date with RevenueCat's.
    purchaseController.syncEntitlements()

    return true
  }

  // MARK: UISceneSession Lifecycle

  func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
  }

  func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {}
}
