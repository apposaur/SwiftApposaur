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
    .package(url: "https://github.com/apposaur/SwiftApposaur.git", from: "0.1.3")
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
// Register a user 
let registerRequest = RegisterSDKUserRequest(
    userId: "your internal user id"
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
        productId: "apple_iap_product_id_here",
        transactionId: "apple_iap_transaction_id_here"
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
// Clear input referral code if needed (this is the code that use put when referred by someone else)
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

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For support, email contact@apposaur.io or visit [https://apposaur.io](https://apposaur.io).
