import Foundation

/// Inactive display contract. Decoding a snapshot never grants an entitlement.
/// Use a plain JSONDecoder: CodingKeys explicitly specify the snake-case wire keys.
struct CommerceUsage: Decodable, Equatable, Sendable {
    enum Plan: String, Decodable, Sendable {
        case free, plus
        var allowance: Int { self == .free ? 5 : 30 }
    }

    enum EntitlementStatus: String, Decodable, Sendable {
        case active, grace, expired, revoked
        case verificationRequired = "verification_required"
    }

    enum AIAvailability: String, Decodable, Sendable {
        case available
        case servicePaused = "service_paused"
        case verificationRequired = "verification_required"
    }

    let plan: Plan
    let allowance: Int
    let successfulGenerations: Int
    let deliveryCreditsUsed: Int
    let consumed: Int
    let reserved: Int
    let remaining: Int
    let periodStart: Int64
    let periodEnd: Int64
    let revision: Int64
    let serverTime: Int64
    let entitlementStatus: EntitlementStatus
    let aiAvailability: AIAvailability

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case plan, allowance, consumed, reserved, remaining, revision
        case successfulGenerations = "successful_generations"
        case deliveryCreditsUsed = "delivery_credits_used"
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case serverTime = "server_time"
        case entitlementStatus = "entitlement_status"
        case aiAvailability = "ai_availability"
    }

    private struct AnyKey: CodingKey {
        let stringValue: String
        let intValue: Int? = nil
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.container(keyedBy: AnyKey.self)
        guard Set(raw.allKeys.map(\.stringValue)) == Set(CodingKeys.allCases.map(\.rawValue)) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath, debugDescription: "Invalid commerce fields."
            ))
        }
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        plan = try fields.decode(Plan.self, forKey: .plan)
        allowance = try fields.decode(Int.self, forKey: .allowance)
        successfulGenerations = try fields.decode(Int.self, forKey: .successfulGenerations)
        deliveryCreditsUsed = try fields.decode(Int.self, forKey: .deliveryCreditsUsed)
        consumed = try fields.decode(Int.self, forKey: .consumed)
        reserved = try fields.decode(Int.self, forKey: .reserved)
        remaining = try fields.decode(Int.self, forKey: .remaining)
        periodStart = try fields.decode(Int64.self, forKey: .periodStart)
        periodEnd = try fields.decode(Int64.self, forKey: .periodEnd)
        revision = try fields.decode(Int64.self, forKey: .revision)
        serverTime = try fields.decode(Int64.self, forKey: .serverTime)
        entitlementStatus = try fields.decode(EntitlementStatus.self, forKey: .entitlementStatus)
        aiAvailability = try fields.decode(AIAvailability.self, forKey: .aiAvailability)

        // Bound every value before doing arithmetic on untrusted integers.
        guard allowance == plan.allowance,
              (0...31).contains(successfulGenerations),
              (0...1).contains(deliveryCreditsUsed),
              (0...31).contains(consumed), (0...1).contains(reserved),
              (0...31).contains(remaining),
              (0...253_402_300_799).contains(periodStart),
              (0...253_402_300_799).contains(periodEnd),
              (0...253_402_300_799).contains(serverTime),
              (0...9_007_199_254_740_991).contains(revision),
              consumed == successfulGenerations - deliveryCreditsUsed,
              remaining == allowance - consumed - reserved,
              periodStart < periodEnd, serverTime >= periodStart else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath, debugDescription: "Inconsistent commerce usage."
            ))
        }
        let usable = entitlementStatus == .active || entitlementStatus == .grace
        guard (!usable || serverTime < periodEnd),
              !(plan == .free && entitlementStatus == .grace),
              (aiAvailability != .available || usable) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath, debugDescription: "Inconsistent commerce state."
            ))
        }
    }
}
