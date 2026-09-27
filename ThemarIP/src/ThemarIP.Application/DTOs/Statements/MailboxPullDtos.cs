using System;
using System.Collections.Generic;

namespace ThemarIP.Application.DTOs.Statements;

public class PullMailboxRequestDto
{
    public string EmailSender { get; set; } = "NOREPLY@BANKMUSCAT.COM";
    public string EmailSubject { get; set; } = "Account Transaction";
    public string Provider { get; set; } = "DEMO"; // ICLOUD, GMAIL, OUTLOOK, APPLE_MAIL, CUSTOM, DEMO
    public string? ImapHost { get; set; }
    public int ImapPort { get; set; } = 993;
    public bool UseSsl { get; set; } = true;
    public string? Username { get; set; }
    public string? Password { get; set; }
    public int MaxEmails { get; set; } = 10;
    public bool AutoFeedDb { get; set; } = true;
    public Guid? UserId { get; set; }
}

public class PullMailboxResultDto
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
    public int TotalFound { get; set; }
    public int IngestedCount { get; set; }
    public List<ParsedNotificationResultDto> Transactions { get; set; } = new();
}
