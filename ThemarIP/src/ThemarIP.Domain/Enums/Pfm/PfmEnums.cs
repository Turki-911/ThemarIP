namespace ThemarIP.Domain.Enums.Pfm;

// ── Transaction ──────────────────────────────────────────────
public enum TransactionType
{
    Debit,
    Credit
}

public enum TransactionStatus
{
    Categorized,
    Uncategorized,
    UserCorrected,
    PendingReview
}

// ── Categorization Engine ─────────────────────────────────────
public enum CategorizationSource
{
    MerchantMapping,   // matched via merchant alias table
    Mcc,               // matched via MCC code
    Rule,              // matched via a CategorizationRule
    Narration,         // keyword match on narration text
    Historical,        // matched from past transactions of same user
    UserRule,          // a global rule created from a user correction
    Manual,            // manually overridden by admin
    Uncategorized      // no signal matched
}

// ── Confidence Bands ──────────────────────────────────────────
public enum ConfidenceBandName
{
    High,
    Medium,
    Low
}

public enum ConfidenceBandAction
{
    AutoCategorize,
    CategorizAndMonitor,
    SendToReview
}

// ── Confidence Weights ────────────────────────────────────────
public enum ConfidenceSignal
{
    MerchantMatch,
    MccMatch,
    NarrationMatch,
    HistoricalMatch,
    AmountPattern
}

// ── Rule Builder ──────────────────────────────────────────────
public enum RuleConditionField
{
    MerchantName,
    MerchantId,
    Narration,
    MccCode,
    TransactionType,
    Amount,
    Currency
}

public enum RuleConditionOperator
{
    Equals,
    Contains,
    StartsWith,
    EndsWith,
    GreaterThan,
    LessThan,
    Between
}

public enum RuleConditionLogic
{
    And,
    Or
}

public enum RuleStatus
{
    Active,
    Inactive
}

// ── User Corrections ──────────────────────────────────────────
public enum CorrectionStatus
{
    Pending,
    Approved,
    Rejected
}

public enum CorrectionScope
{
    UserOnly,   // applies only to the correcting user
    Global      // promoted to a CategorizationRule for all users
}

// ── Learning Suggestions ──────────────────────────────────────
public enum SuggestionStatus
{
    Pending,
    Approved,
    Rejected
}

// ── Intelligence Rules ────────────────────────────────────────
public enum IntelligenceRuleType
{
    HighSpending,
    UnusualSpending,
    LowBalance,
    SpendingIncrease,
    Recurring,
    Custom
}

public enum IntelligenceRuleStatus
{
    Active,
    Inactive
}

public enum IntelligenceRuleParamType
{
    String,
    Number,
    Boolean
}

// ── Audit Log ─────────────────────────────────────────────────
public enum PfmAuditAction
{
    Create,
    Update,
    Delete,
    Approve,
    Reject,
    Toggle
}
