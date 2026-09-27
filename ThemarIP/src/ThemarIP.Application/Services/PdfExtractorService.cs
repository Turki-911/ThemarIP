using System.Collections.Generic;
using System.IO;
using System.Text;
using UglyToad.PdfPig;

namespace ThemarIP.Application.Services;

public interface IPdfExtractorService
{
    List<string> ExtractLines(string filePath);
}

public class PdfExtractorService : IPdfExtractorService
{
    public List<string> ExtractLines(string filePath)
    {
        var lines = new List<string>();
        if (!File.Exists(filePath)) return lines;

        try
        {
            using var pdf = PdfDocument.Open(filePath);
            foreach (var page in pdf.GetPages())
            {
                var text = page.Text;
                if (!string.IsNullOrWhiteSpace(text))
                {
                    var pageLines = text.Split(new[] { "\r\n", "\r", "\n" }, System.StringSplitOptions.RemoveEmptyEntries);
                    foreach (var rawLine in pageLines)
                    {
                        var trimmed = rawLine.Trim();
                        if (!string.IsNullOrWhiteSpace(trimmed))
                        {
                            lines.Add(trimmed);
                        }
                    }
                }
            }
        }
        catch
        {
            // If PDF stream parsing fails, return empty list gracefully to trigger text fallback
        }

        return lines;
    }
}
