# ThemarIP.API - Core Web API

**ThemarIP.API** is a Core Web API built with **Clean Architecture**, **Entity Framework Core**, **PostgreSQL**, **JWT Authentication**, **BCrypt Password Hashing**, **Swagger UI**, and **Role-Based Authorization (Admin/User)**.

---

## 🏛️ Clean Architecture Structure

```
ThemarIP/
├── src/
│   ├── ThemarIP.Domain/          # Core Domain Entities, Enums & Value Objects
│   ├── ThemarIP.Application/     # Application Logic, Interfaces, DTOs & Use Cases
│   ├── ThemarIP.Infrastructure/  # EF Core DbContext, Migrations, BCrypt, JWT & DbInitializer
│   └── ThemarIP.API/             # Controllers, Global Middleware, Swagger & Program.cs
├── docker-compose.yml            # Containerized PostgreSQL + API environment
├── appsettings.json              # Application & Database Configuration
└── README.md                     # Documentation & Setup Guide
```

---

## 🗄️ Entity Relations (ERD)

1. **User**: Has 1-to-Many relationships with `Subscription`, `StatementUpload`, `Transaction`, and `AiQuery`. Roles: `Admin`, `User`.
2. **Subscription**: Belongs to `User`. Tracks plan tier (`Free`, `Pro`, `Enterprise`), status (`Active`, `Expired`, `Cancelled`), and pricing.
3. **StatementUpload**: Belongs to `User`. Has 1-to-Many relationship with `Transaction`. Stores statement metadata and processing status (`Pending`, `Processed`, `Failed`).
4. **Transaction**: Belongs to `StatementUpload` and `User`. Stores transaction date, amount, currency, merchant description, MCC code, and category.
5. **AiQuery**: Belongs to `User`. Logs prompt queries, response summaries, and token usage.
6. **SystemLog**: Application activity and error audit log (`LogLevel`, `Message`, `Exception`, `Source`).

---

## 🔑 Pre-Seeded Accounts

The API automatically applies migrations and seeds test accounts on initial launch:

| Role | Email | Password | Subscription Tier |
|---|---|---|---|
| **Admin** | `admin@themar.ip` | `AdminPassword123!` | Enterprise |
| **User** | `user1@themar.ip` | `UserPassword123!` | Pro |
| **User** | `user2@themar.ip` | `UserPassword123!` | Free |
| **User** | `user3@themar.ip` | `UserPassword123!` | Enterprise |

---

## 🚀 Quick Start Guide

### Option 1: Running with Docker Compose (Recommended)

Start PostgreSQL database and API service in containers:
```bash
docker-compose up --build -d
```
Access Swagger UI at: `http://localhost:8080/swagger`

### Option 2: Running Locally via .NET CLI

1. Ensure PostgreSQL is running on `localhost:5432` with credentials specified in `appsettings.json`.
2. Run the API:
```bash
dotnet run --project src/ThemarIP.API/ThemarIP.API.csproj
```
3. Access Swagger UI at: `http://localhost:5272/swagger` or `http://localhost:5000/swagger`

---

## 📡 API Endpoints Reference

### 🔐 Auth
- `POST /api/auth/register` - Register a new user
- `POST /api/auth/login` - Authenticate user & get JWT bearer token

### 📄 Statements
- `POST /api/statements/upload` - Upload statement file for processing *(Requires Auth)*
- `GET /api/statements` - Retrieve list of statements uploaded by current user *(Requires Auth)*
- `GET /api/statements/{id}` - Retrieve statement details by ID *(Requires Auth)*

### 💳 Transactions
- `GET /api/transactions` - Retrieve all transactions for current user *(Requires Auth)*
- `GET /api/transactions/summary` - Get transaction totals & category stats *(Requires Auth)*
- `GET /api/transactions/categories` - Get spending breakdown by category *(Requires Auth)*

### 💎 Subscriptions
- `GET /api/subscriptions/current` - Get active subscription details for current user *(Requires Auth)*

### 🛡️ Admin *(Requires Admin Role)*
- `GET /api/admin/dashboard` - High-level metrics (total users, statement uploads, transactions, revenue)
- `GET /api/admin/users` - List all registered users
- `GET /api/admin/uploads` - List all statement uploads across system
- `GET /api/admin/subscriptions` - List all system subscriptions
