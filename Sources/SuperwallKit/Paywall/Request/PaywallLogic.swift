//
//  PaywallLogic.swift
//  Paywall
//
//  Created by Yusuf Tör on 03/03/2022.
//

import Foundation
import StoreKit

struct ResponseIdentifiers: Equatable {
  let paywallId: String?
  var experiment: Experiment?

  static var none: ResponseIdentifiers {
    return  .init(paywallId: nil)
  }
}

struct ProductProcessingOutcome {
  var productVariables: [ProductVariable]
  var swProductVariablesTemplate: [ProductVariable]
  var orderedSwProducts: [SWProduct]
  var isFreeTrialAvailable: Bool
}

enum PaywallLogic {
  static func requestHash(
    identifier: String? = nil,
    event: EventData? = nil,
    locale: String,
    paywallProducts: PaywallProducts?
  ) -> String {
    let id = identifier ?? event?.name ?? "$called_manually"
    var substitutions = ""
    if let paywallProducts = paywallProducts {
      substitutions = paywallProducts.ids.joined()
    }
    return "\(id)_\(locale)_\(substitutions)"
  }

  static func handlePaywallError(
    _ error: Error,
    forEvent event: EventData?,
    trackEvent: @escaping (Trackable) async -> TrackingResult = Superwall.shared.track
  ) -> NSError {
    if let error = error as? NetworkError,
      error == .notFound {
      let trackedEvent = InternalSuperwallEvent.PaywallLoad(
        state: .notFound,
        eventData: event
      )
      Task {
        _ = await trackEvent(trackedEvent)
      }
      let userInfo: [String: Any] = [
        NSLocalizedDescriptionKey: NSLocalizedString(
          "Not Found",
          value: "There isn't a paywall configured to show in this context.",
          comment: ""
        )
      ]
      let error = NSError(
        domain: "SWKPaywallNotFound",
        code: 404,
        userInfo: userInfo
      )
      return error
    } else {
      let trackedEvent = InternalSuperwallEvent.PaywallLoad(
        state: .fail,
        eventData: event
      )
      Task {
        _ = await trackEvent(trackedEvent)
      }
      let userInfo: [String: Any] = [
        NSLocalizedDescriptionKey: NSLocalizedString(
          "No Paywall",
          value: "The paywall failed to load.",
          comment: ""
        )
      ]
      let error = NSError(
        domain: "SWKPresentationError",
        code: 107,
        userInfo: userInfo
      )
      return error
    }
  }

  static func getVariablesAndFreeTrial(
    fromProducts products: [Product],
    productsById: [String: StoreProduct],
    isFreeTrialAvailableOverride: Bool?,
    isFreeTrialAvailable: @escaping (StoreProduct) async -> Bool
  ) async -> ProductProcessingOutcome {
    var productVariables: [ProductVariable] = []
    var swTemplateProductVariables: [ProductVariable] = []
    var hasFreeTrial = false
    var orderedSwProducts: [SWProduct] = []

    for product in products {
      // Get skproduct
      guard let storeProduct = productsById[product.id] else {
        continue
      }
      orderedSwProducts.append(storeProduct.swProduct)

      let productVariable = ProductVariable(
        type: product.type,
        attributes: storeProduct.attributesJson
      )
      productVariables.append(productVariable)

      let swTemplateProductVariable = ProductVariable(
        type: product.type,
        attributes: storeProduct.swProductTemplateVariablesJson
      )
      swTemplateProductVariables.append(swTemplateProductVariable)

      if !hasFreeTrial {
        hasFreeTrial = await isFreeTrialAvailable(storeProduct)
      }
    }

    // use the override if it is set
    if let freeTrialOverride = isFreeTrialAvailableOverride {
      hasFreeTrial = freeTrialOverride
    }

    return ProductProcessingOutcome(
      productVariables: productVariables,
      swProductVariablesTemplate: swTemplateProductVariables,
      orderedSwProducts: orderedSwProducts,
      isFreeTrialAvailable: hasFreeTrial
    )
  }
}
