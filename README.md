# Swift Apposaur SDK

A Swift SDK for integrating Apposaur's referral and rewards system into your iOS applications. This SDK provides functionality for managing referral codes, user registration, purchase attribution, and reward redemption with seamless integration to Apple's StoreKit framework.

## Features

- **Referral Code Management**: Validate and manage referral codes
- **User Registration**: Register users with referral attribution
- **Purchase Attribution**: Track and attribute purchases to referral sources
- **Rewards System**: Get and redeem reward offers
- **StoreKit Integration**: Seamless integration with Apple's StoreKit 2 framework
- **iOS Only**: Currently supports iOS platform only
- **Automatic Subscription Detection**: Automatically detects active subscriptions
- **Transaction Deduplication**: Prevents duplicate transaction processing

## Requirements

- iOS 15.0+
- Swift 6.1+
- Xcode 14.0+
- StoreKit 2 framework

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/your-username/SwiftApposaur.git", from: "1.0.0")
]
```

Or add it directly in Xcode:
1. Go to File → Add Package Dependencies
2. Enter the repository URL
3. Select the version you want to use

## Quick Start

### 1. Import and Initialize the SDK

```swift
import SwiftApposaur

// Initialize with your API key
do {
    try await ApposaurSDK.shared.initialize(apiKey: "your-api-key-here")
    print("SDK initialized successfully")
} catch {
    print("Failed to initialize SDK: \(error)")
}
```

### 2. Validate Referral Codes

```swift
// Validate a referral code
let request = ValidateReferralCodeRequest(code: "REFERRAL123")
do {
    let isValid = try await ApposaurSDK.shared.validateReferralCode(request)
    if isValid {
        print("Referral code is valid")
    } else {
        print("Invalid referral code")
    }
} catch {
    print("Error validating referral code: \(error)")
}
```

### 3. Register Users

```swift
// Register a user (with optional Apple subscription ID)
let registerRequest = RegisterSDKUserRequest(
    userId: "user123",
    appleSubscriptionOriginalTransactionId: "optional_subscription_id"
)

do {
    try await ApposaurSDK.shared.registerUser(registerRequest)
    print("User registered successfully")
} catch {
    print("Error registering user: \(error)")
}
```

### 4. Attribute Purchases

```swift
// Attribute a purchase to track referral conversions
do {
    try await ApposaurSDK.shared.attributePurchase(
        productId: "product_id_here",
        transactionId: "transaction_id_here"
    )
    print("Purchase attributed successfully")
} catch {
    print("Error attributing purchase: \(error)")
}
```

### 5. Get User's Referral Code

```swift
// Get the referral code for the registered user
if let referralCode = ApposaurSDK.shared.getRegisteredUserReferralCode() {
    print("User referral code: \(referralCode)")
} else {
    print("No referral code found for user")
}
```

### 6. Manage Rewards

```swift
// Get available rewards for the user
do {
    let rewardsResponse = try await ApposaurSDK.shared.getRewards()
    print("Available rewards: \(rewardsResponse.rewards)")
    
    for reward in rewardsResponse.rewards {
        print("Reward: \(reward.offerName) (ID: \(reward.appRewardId))")
    }
} catch {
    print("Error getting rewards: \(error)")
}

// Redeem a reward offer (iOS 15.0+)
if #available(iOS 15.0, *) {
    do {
        try await ApposaurSDK.shared.redeemRewardOffer(rewardId: "reward_id_here")
        print("Reward redeemed successfully")
    } catch {
        print("Error redeeming reward: \(error)")
    }
}
```

### 7. Clear Referral Code

```swift
// Clear stored referral code if needed
ApposaurSDK.shared.clearReferralCode()
```

## Data Models

### ValidateReferralCodeRequest
```swift
public struct ValidateReferralCodeRequest {
    public let code: String
}
```

### RegisterSDKUserRequest
```swift
public struct RegisterSDKUserRequest {
    public let userId: String
    public let appleSubscriptionOriginalTransactionId: String?
}
```

### GetRewardsResponse
```swift
public struct GetRewardsResponse {
    public let rewards: [GetRewardsItem]
}

public struct GetRewardsItem {
    public let appRewardId: String
    public let offerName: String
}
```

## Error Handling

The SDK provides comprehensive error handling with the `ApposaurSDKError` enum:

```swift
public enum ApposaurSDKError: Error, LocalizedError {
    case initializationFailed(String)
    case invalidAPIKey
    case networkError(String)
    case validationFailed(String)
    case noActiveSubscription
    case appUserIdNotFound
    case purchaseFailed(String)
}
```

## Key Features

### Automatic Subscription Detection
The SDK automatically detects active subscriptions using StoreKit 2's `Transaction.currentEntitlements` and uses the subscription product ID for reward operations.

### Transaction Deduplication
The SDK maintains a list of processed transactions to prevent duplicate processing of the same purchase.

### Persistent Storage
User data, referral codes, and processed transactions are stored in `UserDefaults` for persistence across app sessions.

### Retry Logic
Network requests include automatic retry logic with exponential backoff for improved reliability.

## Integration with StoreKit 2

The SDK is designed to work seamlessly with StoreKit 2:

- Automatically detects active subscriptions
- Integrates with promotional offers for reward redemption
- Handles purchase verification and completion
- Supports subscription management workflows

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For support, email contact@apposaur.io or visit [https://apposaur.io](https://apposaur.io).
