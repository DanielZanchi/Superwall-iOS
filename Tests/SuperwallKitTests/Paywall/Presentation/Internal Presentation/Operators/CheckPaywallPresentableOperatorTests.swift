//
//  File.swift
//  
//
//  Created by Yusuf Tör on 06/12/2022.
//

import XCTest
@testable import SuperwallKit
import Combine

final class CheckPaywallPresentableOperatorTests: XCTestCase {
  var cancellables: [AnyCancellable] = []
  let superwall = Superwall.shared

  @MainActor
  func test_checkPaywallIsPresentable_userIsSubscribed() async {
    let experiment = Experiment(id: "", groupId: "", variant: .init(id: "", type: .treatment, paywallId: ""))

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")

    statePublisher.sink { state in
      switch state {
      case .skipped(let reason):
        switch reason {
        case .userIsSubscribed:
          stateExpectation.fulfill()
        default:
          break
        }
      default:
        break
      }
    }
    .store(in: &cancellables)

    let publisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.active)
      .eraseToAnyPublisher()
    let dependencyContainer = DependencyContainer()
    let request = PresentationRequest.stub()
      .setting(\.flags.subscriptionStatus, to: publisher)

    let paywallVc = dependencyContainer.makePaywallViewController(
      for: .stub(),
      withCache: nil,
      withPaywallArchivalManager: nil,
      delegate: nil
    )
    paywallVc.loadViewIfNeeded()
    let expectation = expectation(description: "Called publisher")
    do {
      try await Superwall.shared.getPresenterIfNecessary(
        for: paywallVc,
        rulesOutcome: RuleEvaluationOutcome(triggerResult: .paywall(experiment)),
        request: request,
        debugInfo: [:],
        paywallStatePublisher: statePublisher
      )
      XCTFail("Should throw")
    } catch {
      if let error = error as? PresentationPipelineError,
        case .userIsSubscribed = error {
        expectation.fulfill()
      }
    }

    await fulfillment(of: [expectation, stateExpectation], timeout: 2)
  }

  @MainActor
  func test_checkPaywallIsPresentable_noPresenter() async {
    let experiment = Experiment(id: "", groupId: "", variant: .init(id: "", type: .treatment, paywallId: ""))

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.expectedFulfillmentCount = 2

    statePublisher.sink { completion in
      switch completion {
      case .finished:
        stateExpectation.fulfill()
      }
    } receiveValue: { state in
      switch state {
      case .presentationError:
        stateExpectation.fulfill()
      default:
        break
      }
    }
    .store(in: &cancellables)

    Superwall.shared.presentationItems.window = UIWindow()

    let inactiveSubscriptionPublisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.inactive)
      .eraseToAnyPublisher()
    let dependencyContainer = DependencyContainer()
    let request = dependencyContainer.makePresentationRequest(
      .explicitTrigger(.stub()),
      isDebuggerLaunched: false,
      subscriptionStatus: inactiveSubscriptionPublisher,
      isPaywallPresented: false,
      type: .presentation
    )
    .setting(\.presenter, to: nil)

    let paywallVc = dependencyContainer.makePaywallViewController(
      for: .stub(),
      withCache: nil,
      withPaywallArchivalManager: nil,
      delegate: nil
    )
    paywallVc.loadViewIfNeeded()
    let expectation = expectation(description: "Called publisher")
    do {
      try await Superwall.shared.getPresenterIfNecessary(
        for: paywallVc,
        rulesOutcome: RuleEvaluationOutcome(triggerResult: .paywall(experiment)),
        request: request,
        debugInfo: [:],
        paywallStatePublisher: statePublisher
      )
      XCTFail("Should throw")
    } catch {
      if let error = error as? PresentationPipelineError,
         case .noPresenter = error {
        expectation.fulfill()
      }
    }

    await fulfillment(of: [expectation, stateExpectation], timeout: 2)
  }

  @MainActor
  func test_checkPaywallIsPresentable_success() async {
    let experiment = Experiment(id: "", groupId: "", variant: .init(id: "", type: .treatment, paywallId: ""))

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.isInverted = true

    statePublisher.sink { completion in
      stateExpectation.fulfill()
    } receiveValue: { state in
      stateExpectation.fulfill()
    }
    .store(in: &cancellables)

    let publisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.inactive)
      .eraseToAnyPublisher()
    let request = PresentationRequest.stub()
      .setting(\.presenter, to: UIViewController())
      .setting(\.flags.subscriptionStatus, to: publisher)

    let dependencyContainer = DependencyContainer()
    let paywallVc = dependencyContainer.makePaywallViewController(
      for: .stub(),
      withCache: nil,
      withPaywallArchivalManager: nil,
      delegate: nil
    )
    paywallVc.loadViewIfNeeded()
    do {
      try await Superwall.shared.getPresenterIfNecessary(
        for: paywallVc,
        rulesOutcome: RuleEvaluationOutcome(triggerResult: .paywall(experiment)),
        request: request,
        debugInfo: [:],
        paywallStatePublisher: statePublisher
      )
    } catch {
      XCTFail()
    }

    await fulfillment(of: [stateExpectation], timeout: 2)
  }
}
