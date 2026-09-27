namespace ThemarIP.Domain.Enums;

public enum SubscriptionTier
{
    Free,
    Pro,
    Enterprise
}

public enum SubscriptionStatus
{
    Active,
    Expired,
    Cancelled
}

public enum StatementStatus
{
    Pending,
    Processed,
    Failed
}

public enum AccessStatus
{
    Pending,
    Approved,
    Rejected
}

public enum AccessReasonCode
{
    KycNotClear,
    SuspiciousActivity,
    DuplicateAccount,
    IncompleteInformation,
    Other
}

public enum KycStatus
{
    Pending,
    Verified,
    Rejected
}

public enum AuditActionType
{
    ApproveAccess,
    RejectAccess,
    ApproveKyc,
    RejectKyc
}
