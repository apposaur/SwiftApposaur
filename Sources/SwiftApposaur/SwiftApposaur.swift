import Foundation
import StoreKit


private struct Constants {
    static let baseURL = "https://api.apposaur.io/sdk"
    static let apiHeaderKey = "x-api-key"
    static let sdkPlatformHeaderKey = "x-sdk-platform"
    
    static let sdkReferralCodeKey = "APPOAUR_SDK_REFERRAL_CODE"
    static let sdkReferredByUserIdKey = "APPOAUR_SDK_REFERRED_BY_USER_ID"
    static let sdkAppUserCodeKey = "APPOAUR_SDK_USER_CODE"
    static let sdkAppUserIdKey = "APPOAUR_SDK_USER_ID"
    static let sdkProcessedTransactionsKey = "APPOSAUR_SDK_PROCESSED_TRANSACTIONS"
}

public struct ValidateAppKeyResponse {
    public let valid: Bool
}

public struct RegisterSDKUserRequest {
    public let userId: String
    public let appleSubscriptionOriginalTransactionId: String?
    
    public init(userId: String, appleSubscriptionOriginalTransactionId: String? = nil) {
        self.userId = userId
        self.appleSubscriptionOriginalTransactionId = appleSubscriptionOriginalTransactionId
    }
}

public struct RegisterSDKUserResponse {
    public let appId: String
    public let externalUserId: String
    public let appUserId: String
    public let code: String
    public let appleSubscriptionOriginalTransactionId: String?
    public let createdAt: String?
}

public struct ValidateReferralCodeRequest {
    public let code: String
    
    public init(code: String) {
        self.code = code
    }
}

public struct GetRewardsItem {
    public let appRewardId: String
    public let offerName: String
}

public struct GetRewardsResponse {
    public let rewards: [GetRewardsItem]
}

public struct SignedOffer {
    public let offerId: String
    public let keyIdentifier: String
    public let nonce: String
    public let signature: String
    public let timestamp: Int64
}

public struct RedeemRewardOfferRequest {
    public let appRewardId: String
    
    public init(appRewardId: String) {
        self.appRewardId = appRewardId
    }
}

public struct RedeemRewardOfferResponse {
    public let success: Bool
}

public enum ApposaurSDKError: Error, LocalizedError {
    case initializationFailed(String)
    case invalidAPIKey
    case networkError(String)
    case validationFailed(String)
    case noActiveSubscription
    case appUserIdNotFound
    case purchaseFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .initializationFailed(let message):
            return "Initialization failed: \(message)"
        case .invalidAPIKey:
            return "Invalid API key"
        case .networkError(let message):
            return "Network error: \(message)"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .noActiveSubscription:
            return "No active subscription found"
        case .appUserIdNotFound:
            return "App user ID not found"
        case .purchaseFailed(let message):
            return "Purchase failed: \(message)"
        }
    }
}

public actor ApposaurSDK {
    
    public static let shared = ApposaurSDK()
    private init() {}
    
    private var apiKey: String?
    private var activeSubscriptionProductId: String = ""
    private let userDefaults = UserDefaults.standard
    private let session = URLSession.shared
    
    
    /// Initialize the SDK with API key
    public func initialize(apiKey: String) async throws {
        self.apiKey = apiKey
        
        try await validateAPIKey()
        
        do {
            self.activeSubscriptionProductId = try await getActiveSubscriptionProductId()
        } catch {
            // Ignore error - user might not have active subscription
            print("No active subscription found: \(error)")
        }
    }
    
    /// Validate referral code
    public func validateReferralCode(_ request: ValidateReferralCodeRequest) async throws -> Bool {
        let requestBody = ["code": request.code]
        
        let data = try await makeRequest(
            endpoint: "/referral/validate",
            method: "POST",
            body: requestBody
        )
        
        guard let referredAppUserId = data["referred_app_user_id"] as? String else {
            return false
        }
        
        userDefaults.set(request.code, forKey: Constants.sdkReferralCodeKey)
        userDefaults.set(referredAppUserId, forKey: Constants.sdkReferredByUserIdKey)
        
        return true
    }
    
    /// Clear referral code
    public func clearReferralCode() {
        userDefaults.removeObject(forKey: Constants.sdkReferralCodeKey)
        userDefaults.removeObject(forKey: Constants.sdkReferredByUserIdKey)
    }
    
    /// Register user
    public func registerUser(_ request: RegisterSDKUserRequest) async throws {
        let referredByUserId = userDefaults.string(forKey: Constants.sdkReferredByUserIdKey)
        
        let apiRequest: [String: Any] = [
            "external_user_id": request.userId,
            "original_transaction_id": request.appleSubscriptionOriginalTransactionId as Any,
            "referred_app_user_id": referredByUserId as Any
        ]
        
        do {
            let response = try await makeRequest(
                endpoint: "/referral/register",
                method: "POST",
                body: apiRequest
            )
            
            if let appUserId = response["app_user_id"] as? String {
                userDefaults.set(appUserId, forKey: Constants.sdkAppUserIdKey)
            }
            
            if let code = response["code"] as? String {
                userDefaults.set(code, forKey: Constants.sdkAppUserCodeKey)
            }
        } catch {
            print("Error registering user: \(error)")
        }
    }
    
    /// Get registered user referral code
    public func getRegisteredUserReferralCode() -> String? {
        return userDefaults.string(forKey: Constants.sdkAppUserCodeKey)
    }
    
    /// Attribute purchase
    public func attributePurchase(productId: String, transactionId: String) async throws {
        guard let appUserId = userDefaults.string(forKey: Constants.sdkAppUserIdKey) else {
            return
        }
        
        // Check if transaction was already processed
        let processedTransactions = getProcessedTransactions()
        if processedTransactions.contains(transactionId) {
            return
        }
        
        let attributePurchaseRequest: [String: Any] = [
            "app_user_id": appUserId,
            "product_id": productId,
            "transaction_id": transactionId
        ]
        
        self.activeSubscriptionProductId = productId
        
        try await sendPurchaseEvent(attributePurchaseRequest)
        
        var updatedTransactions = processedTransactions
        updatedTransactions.append(transactionId)
        setProcessedTransactions(updatedTransactions)
    }
    
    /// Get rewards
    public func getRewards() async throws -> GetRewardsResponse {
        guard let appUserId = userDefaults.string(forKey: Constants.sdkAppUserIdKey) else {
            return GetRewardsResponse(rewards: [])
        }
        
        guard !activeSubscriptionProductId.isEmpty else {
            return GetRewardsResponse(rewards: [])
        }
                
        let url = "/referral/rewards?app_user_id=\(appUserId)&product_id=\(activeSubscriptionProductId)"
        let data = try await makeRequest(endpoint: url, method: "GET")
        
        guard let rewardsData = data["rewards"] as? [[String: Any]] else {
            return GetRewardsResponse(rewards: [])
        }
        
        let rewards = rewardsData.compactMap { rewardDict -> GetRewardsItem? in
            guard let appRewardId = rewardDict["app_reward_id"] as? String,
                  let offerName = rewardDict["offer_name"] as? String else {
                return nil
            }
            return GetRewardsItem(appRewardId: appRewardId, offerName: offerName)
        }
        
        return GetRewardsResponse(rewards: rewards)
    }
    
    /// Redeem reward offer
    @available(iOS 15.0, *)
    public func redeemRewardOffer(rewardId: String) async throws {
        guard let appUserId = userDefaults.string(forKey: Constants.sdkAppUserIdKey) else {
            throw ApposaurSDKError.appUserIdNotFound
        }
        
        guard !activeSubscriptionProductId.isEmpty else {
            throw ApposaurSDKError.noActiveSubscription
        }
        
        // Get products to ensure subscription is available
        let products = try await Product.products(for: [activeSubscriptionProductId])
        guard let product = products.first else {
            throw ApposaurSDKError.noActiveSubscription
        }
        
        let signRewardOfferRequest: [String: Any] = [
            "app_reward_id": rewardId,
            "product_id": activeSubscriptionProductId,
            "app_user_id": appUserId
        ]
        
        let signedOfferData = try await makeRequest(
            endpoint: "/referral/rewards/sign",
            method: "POST",
            body: signRewardOfferRequest
        )
        
        guard let offerId = signedOfferData["offerId"] as? String,
              let keyIdentifier = signedOfferData["keyIdentifier"] as? String,
              let nonce = signedOfferData["nonce"] as? String,
              let signature = signedOfferData["signature"] as? String,
              let timestamp = signedOfferData["timestamp"] as? Int64 else {
            throw ApposaurSDKError.networkError("Invalid signed offer response")
        }
        
        var options: Set<Product.PurchaseOption> = []
        // Create promotional offer
        options.insert(.promotionalOffer(offerID: offerId, keyID: keyIdentifier, nonce: UUID(uuidString: nonce) ?? UUID(), signature: Data(signature.utf8), timestamp: Int(timestamp) ))
        
        do {
            let purchaseResult = try await product.purchase(options: options)
            
            switch purchaseResult {
            case .success(let verification):
                try await makeRequest(
                    endpoint: "/referral/rewards/redeem",
                    method: "POST",
                    body: ["app_reward_id": rewardId]
                )
            case .userCancelled:
                throw ApposaurSDKError.purchaseFailed("User cancelled purchase")
            case .pending:
                throw ApposaurSDKError.purchaseFailed("Purchase is pending")
            @unknown default:
                throw ApposaurSDKError.purchaseFailed("Unknown purchase result")
            }
        } catch {
            throw ApposaurSDKError.purchaseFailed(error.localizedDescription)
        }
    }
        
    private func validateAPIKey() async throws {
        let data = try await makeRequest(endpoint: "/referral/key", method: "POST")
        
        guard let valid = data["valid"] as? Bool, valid else {
            throw ApposaurSDKError.invalidAPIKey
        }
    }
    
    private func getActiveSubscriptionProductId() async throws -> String {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productType == .autoRenewable,
               transaction.revocationDate == nil,
               transaction.expirationDate ?? Date() > Date() {
                return transaction.productID
            }
        }
        throw ApposaurSDKError.noActiveSubscription
    }
    
    private func sendPurchaseEvent(_ request: [String: Any]) async throws {
        try await makeRequest(
            endpoint: "/referral/purchase",
            method: "POST",
            body: request
        )
    }
    
    private func makeRequest(
        endpoint: String,
        method: String,
        body: [String: Any]? = nil,
        retryCount: Int = 2
    ) async throws -> [String: Any] {
        
        guard let apiKey = self.apiKey else {
            throw ApposaurSDKError.initializationFailed("API key not set")
        }
        
        guard let url = URL(string: Constants.baseURL + endpoint) else {
            throw ApposaurSDKError.networkError("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: Constants.apiHeaderKey)
        request.setValue("ios", forHTTPHeaderField: Constants.sdkPlatformHeaderKey)
        
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ApposaurSDKError.networkError("Invalid response")
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw ApposaurSDKError.networkError("HTTP error: \(httpResponse.statusCode)")
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw ApposaurSDKError.networkError("Invalid JSON response")
            }
            
            return json
            
        } catch {
            if retryCount > 0 {
                print("Request failed, retrying... \(error)")
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                return try await makeRequest(endpoint: endpoint, method: method, body: body, retryCount: retryCount - 1)
            } else {
                throw ApposaurSDKError.networkError("Request failed after retries: \(error.localizedDescription)")
            }
        }
    }
    
    private func getProcessedTransactions() -> [String] {
        guard let data = userDefaults.data(forKey: Constants.sdkProcessedTransactionsKey),
              let transactions = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return transactions
    }
    
    private func setProcessedTransactions(_ transactions: [String]) {
        guard let data = try? JSONEncoder().encode(transactions) else { return }
        userDefaults.set(data, forKey: Constants.sdkProcessedTransactionsKey)
    }
}
