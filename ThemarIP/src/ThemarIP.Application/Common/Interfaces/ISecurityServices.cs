using ThemarIP.Domain.Entities;

namespace ThemarIP.Application.Common.Interfaces;

public interface IPasswordHasher
{
    string HashPassword(string password);
    bool VerifyPassword(string password, string hashedPassword);
}

public interface IJwtTokenGenerator
{
    string GenerateToken(User user);
    string GenerateLongLivedToken(User user, int days = 365);
}
