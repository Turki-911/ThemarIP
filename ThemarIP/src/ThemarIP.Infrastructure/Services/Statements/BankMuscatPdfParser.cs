using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using ThemarIP.Application.DTOs.Statements;
using ThemarIP.Application.Interfaces.Statements;
using UglyToad.PdfPig;
using UglyToad.PdfPig.Content;

namespace ThemarIP.Infrastructure.Services.Statements;

public class BankMuscatPdfParser : IBankMuscatPdfParser
{
    private static readonly Regex DateRegex = new(@"^\d{2}/\d{2}/\d{4}$", RegexOptions.Compiled);

    public StatementResultDto ParsePdf(Stream pdfStream)
    {
        var result = new StatementResultDto();

        try
        {
            using var document = PdfDocument.Open(pdfStream);

            bool headerParsed = false;
            var rawExtractedTransactions = new List<ParsedTransactionDto>();

            for (int pageNum = 1; pageNum <= document.NumberOfPages; pageNum++)
            {
                var page = document.GetPage(pageNum);
                var words = page.GetWords().ToList();

                if (!words.Any()) continue;

                if (!headerParsed)
                {
                    ParseHeader(words, result.Header);
                    headerParsed = true;
                }

                ParsePageTransactions(words, rawExtractedTransactions);
            }

            result.Transactions = rawExtractedTransactions;
            ReconcileAndValidateBalances(result);
        }
        catch (Exception ex)
        {
            result.HasValidationErrors = true;
            result.ErrorMessage = $"Failed to parse PDF statement: {ex.Message}";
            result.ExtractionConfidence = 0;
            result.ReconciliationStatus = "FAILED";
        }

        return result;
    }

    private void ParseHeader(List<Word> words, StatementHeaderDto header)
    {
        var lines = GroupWordsIntoLines(words);
        foreach (var line in lines)
        {
            if (line.Contains("Statement Cycle"))
                header.StatementCycle = ExtractValue(line, "Statement Cycle");
            else if (line.Contains("Statement Date"))
                header.StatementDate = ExtractValue(line, "Statement Date");
        }

        // Account Number: 13-18 digit account number at X [200..370]
        var accNumWord = words.FirstOrDefault(w =>
            w.BoundingBox.Left >= 200 && w.BoundingBox.Right <= 370 &&
            Regex.IsMatch(w.Text.Trim(), @"^\d{13,18}$"));
        if (accNumWord != null)
        {
            header.AccountNumber = accNumWord.Text.Trim();
        }

        // IBAN: starts with OM and has digits at X [60..260]
        var ibanWord = words.FirstOrDefault(w =>
            w.BoundingBox.Left >= 60 && w.BoundingBox.Right <= 260 &&
            Regex.IsMatch(w.Text.Trim(), @"^OM\d{15,25}$", RegexOptions.IgnoreCase));
        if (ibanWord != null)
        {
            header.Iban = ibanWord.Text.Trim();
        }

        // Customer Name: words at X < 350 on line at Y ~ 1415-1445
        var nameWords = words
            .Where(w => w.BoundingBox.Bottom >= 1415 && w.BoundingBox.Bottom <= 1445 && w.BoundingBox.Left < 350)
            .OrderBy(w => w.BoundingBox.Left)
            .Select(w => w.Text)
            .ToList();
        var fullName = string.Join(" ", nameWords).Trim();
        if (!string.IsNullOrWhiteSpace(fullName))
        {
            header.AccountName = fullName;
        }

        header.Currency = "OMR";
    }

    private void ParsePageTransactions(List<Word> words, List<ParsedTransactionDto> transactions)
    {
        // 1. Establish Table Boundary on Page
        // Header line typically contains "Post Date", "Value Date", "Narration", "Debit", "Credit", "Balance"
        var headerPostDate = words.FirstOrDefault(w =>
            w.Text.Equals("Post", StringComparison.OrdinalIgnoreCase) && w.BoundingBox.Left < 155);

        double tableTopY = headerPostDate != null ? headerPostDate.BoundingBox.Bottom - 4 : 1400;
        double tableBottomY = 80; // Stop above footer discrepancy warning

        // Footer check
        var footerWord = words.FirstOrDefault(w =>
            w.Text.Equals("discrepancy", StringComparison.OrdinalIgnoreCase) ||
            w.Text.Equals("care@bankmuscat.com", StringComparison.OrdinalIgnoreCase));
        if (footerWord != null)
        {
            tableBottomY = Math.Max(tableBottomY, footerWord.BoundingBox.Top + 5);
        }

        var tableWords = words
            .Where(w => w.BoundingBox.Bottom < tableTopY && w.BoundingBox.Bottom > tableBottomY)
            .ToList();

        if (!tableWords.Any()) return;

        // 2. Group into Horizontal Lines by Y Coordinate (3.5pt vertical snap)
        var horizontalLines = tableWords
            .GroupBy(w => Math.Round(w.BoundingBox.Bottom / 3.5) * 3.5)
            .OrderByDescending(g => g.Key)
            .ToList();

        // 3. Detect Anchor Lines (Posting Date at X < 155 AND Balance at X > 760)
        var anchors = new List<TransactionRowAnchor>();

        foreach (var lineGroup in horizontalLines)
        {
            var lineWords = lineGroup.OrderBy(w => w.BoundingBox.Left).ToList();

            var dateWord = lineWords.FirstOrDefault(w =>
                w.BoundingBox.Left >= 50 && w.BoundingBox.Right <= 155 && DateRegex.IsMatch(w.Text.Trim()));

            var balWord = lineWords.FirstOrDefault(w =>
                w.BoundingBox.Left >= 760 && w.BoundingBox.Right <= 890);

            if (dateWord != null && balWord != null && decimal.TryParse(balWord.Text.Replace(",", ""), out var balance))
            {
                var valDateWord = lineWords.FirstOrDefault(w =>
                    w.BoundingBox.Left >= 145 && w.BoundingBox.Right <= 235 && DateRegex.IsMatch(w.Text.Trim()));

                // Strict Column Coordinates:
                // Debit Column: X [550 .. 655]
                // Credit Column: X [655 .. 760]
                var debitWord = lineWords.FirstOrDefault(w => w.BoundingBox.Left >= 550 && w.BoundingBox.Right <= 655);
                var creditWord = lineWords.FirstOrDefault(w => w.BoundingBox.Left >= 655 && w.BoundingBox.Right <= 760);

                decimal? debitVal = null;
                if (debitWord != null && decimal.TryParse(debitWord.Text.Replace(",", ""), out var d))
                    debitVal = d;

                decimal? creditVal = null;
                if (creditWord != null && decimal.TryParse(creditWord.Text.Replace(",", ""), out var c))
                    creditVal = c;

                DateTime.TryParse(dateWord.Text.Trim(), out var pDate);
                DateTime.TryParse(valDateWord != null ? valDateWord.Text.Trim() : dateWord.Text.Trim(), out var vDate);

                anchors.Add(new TransactionRowAnchor
                {
                    Y = lineGroup.Key,
                    PostDate = pDate,
                    ValueDate = vDate,
                    Debit = debitVal,
                    Credit = creditVal,
                    Balance = balance
                });
            }
        }

        // Sort anchors top to bottom
        anchors = anchors.OrderByDescending(a => a.Y).ToList();

        // 4. Reconstruct Each Independent Row by Vertical Coordinate Slicing
        for (int i = 0; i < anchors.Count; i++)
        {
            var currentAnchor = anchors[i];

            // Boundaries: halfway to preceding anchor (top) and halfway to following anchor (bottom)
            double sliceTop = (i == 0)
                ? tableTopY
                : (anchors[i - 1].Y + currentAnchor.Y) / 2.0;

            double sliceBottom = (i == anchors.Count - 1)
                ? tableBottomY
                : (currentAnchor.Y + anchors[i + 1].Y) / 2.0;

            // Narration Column: X in [220 .. 560]
            var narrationWords = tableWords
                .Where(w => w.BoundingBox.Bottom <= sliceTop && w.BoundingBox.Bottom > sliceBottom)
                .Where(w => w.BoundingBox.Left >= 220 && w.BoundingBox.Left < 560)
                .OrderByDescending(w => w.BoundingBox.Bottom)
                .ThenBy(w => w.BoundingBox.Left)
                .ToList();

            // Group narration words line-by-line to preserve natural reading order
            var narrationLines = narrationWords
                .GroupBy(w => Math.Round(w.BoundingBox.Bottom / 3.0) * 3.0)
                .OrderByDescending(g => g.Key)
                .Select(g => string.Join(" ", g.OrderBy(w => w.BoundingBox.Left).Select(w => w.Text)))
                .Where(s => !string.IsNullOrWhiteSpace(s))
                .ToList();

            string fullNarration = string.Join(" ", narrationLines).Trim();

            // Determine Direction and Amount strictly from Column Mapping
            string direction = "DEBIT";
            decimal amount = 0m;

            if (currentAnchor.Debit.HasValue && !currentAnchor.Credit.HasValue)
            {
                direction = "DEBIT";
                amount = currentAnchor.Debit.Value;
            }
            else if (currentAnchor.Credit.HasValue && !currentAnchor.Debit.HasValue)
            {
                direction = "CREDIT";
                amount = currentAnchor.Credit.Value;
            }
            else if (currentAnchor.Debit.HasValue && currentAnchor.Credit.HasValue)
            {
                // Fallback: use larger or non-zero value
                if (currentAnchor.Debit.Value > 0)
                {
                    direction = "DEBIT";
                    amount = currentAnchor.Debit.Value;
                }
                else
                {
                    direction = "CREDIT";
                    amount = currentAnchor.Credit.Value;
                }
            }

            transactions.Add(new ParsedTransactionDto
            {
                PostDate = currentAnchor.PostDate,
                ValueDate = currentAnchor.ValueDate,
                Narration = fullNarration,
                Direction = direction,
                Amount = amount,
                Debit = currentAnchor.Debit,
                Credit = currentAnchor.Credit,
                Balance = currentAnchor.Balance,
                IsBalanceValid = true,
                ExtractionStatus = "PASS",
                ExtractionConfidence = 100
            });
        }
    }

    private void ReconcileAndValidateBalances(StatementResultDto result)
    {
        decimal? previousBalance = null;

        for (int i = 0; i < result.Transactions.Count; i++)
        {
            var tx = result.Transactions[i];

            if (previousBalance.HasValue)
            {
                tx.PreviousBalance = previousBalance.Value;

                // Mathematical formula: PreviousBalance + Credit - Debit = CurrentBalance
                decimal expected = previousBalance.Value + (tx.Credit ?? 0) - (tx.Debit ?? 0);
                tx.ExpectedBalance = expected;

                decimal diff = Math.Abs(expected - tx.Balance);
                if (diff <= 0.002m)
                {
                    tx.IsBalanceValid = true;
                    tx.ExtractionStatus = "PASS";
                    tx.ExtractionConfidence = 100;
                    tx.ValidationMessage = string.Empty;
                }
                else
                {
                    tx.IsBalanceValid = false;
                    tx.ExtractionStatus = "EXTRACTION_REVIEW_REQUIRED";
                    tx.ExtractionConfidence = 60;
                    tx.ValidationMessage = $"Reconciliation mismatch: expected balance {expected:F3}, but got {tx.Balance:F3} (diff: {diff:F3})";
                    result.HasValidationErrors = true;
                }
            }
            else
            {
                // First transaction in document establishes baseline balance
                tx.IsBalanceValid = true;
                tx.ExtractionStatus = "PASS";
                tx.ExtractionConfidence = 100;
            }

            previousBalance = tx.Balance;
        }

        result.TotalCount = result.Transactions.Count;
        result.ValidCount = result.Transactions.Count(t => t.IsBalanceValid);
        result.ExtractionConfidence = result.TotalCount > 0
            ? (int)Math.Round(result.Transactions.Average(t => t.ExtractionConfidence))
            : 100;

        result.ReconciliationStatus = (result.ValidCount == result.TotalCount && result.TotalCount > 0)
            ? "RECONCILED"
            : "REVIEW_REQUIRED";
    }

    private string ExtractValue(string line, string key)
    {
        var idx = line.IndexOf(key, StringComparison.OrdinalIgnoreCase);
        if (idx >= 0)
        {
            var substring = line.Substring(idx + key.Length).Trim(' ', ':', '-');
            return substring;
        }
        return string.Empty;
    }

    private List<string> GroupWordsIntoLines(List<Word> words)
    {
        var lines = new List<string>();
        if (!words.Any()) return lines;

        var orderedWords = words
            .OrderByDescending(w => w.BoundingBox.Bottom)
            .ThenBy(w => w.BoundingBox.Left)
            .ToList();

        double currentY = orderedWords.First().BoundingBox.Bottom;
        var currentLine = new List<string>();

        foreach (var word in orderedWords)
        {
            if (Math.Abs(word.BoundingBox.Bottom - currentY) > 5)
            {
                lines.Add(string.Join(" ", currentLine));
                currentLine.Clear();
                currentY = word.BoundingBox.Bottom;
            }
            currentLine.Add(word.Text);
        }

        if (currentLine.Any())
        {
            lines.Add(string.Join(" ", currentLine));
        }

        return lines;
    }

    private class TransactionRowAnchor
    {
        public double Y { get; set; }
        public DateTime PostDate { get; set; }
        public DateTime ValueDate { get; set; }
        public decimal? Debit { get; set; }
        public decimal? Credit { get; set; }
        public decimal Balance { get; set; }
    }
}
