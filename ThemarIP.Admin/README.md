# ThemarIP.Admin - Fintech Web Admin Dashboard

**ThemarIP.Admin** is a professional fintech web admin dashboard designed for operational management, analytical reporting, user administration, and statement tracking. It connects directly to `ThemarIP.API` backend REST endpoints.

---

## ✨ Features

- **Fintech Dark Design System**: Built with modern Inter typography, glassmorphism card elevation, and responsive flex/grid layouts.
- **KPI Metrics Cards**: Real-time display of Total Revenue, Total Registered Users, Processed Statement Uploads, and Ingested Transactions.
- **4 Analytical Charts**:
  - *Revenue Performance*: Area line chart showing monthly revenue growth.
  - *Top Spending Categories*: Doughnut chart detailing category breakdown.
  - *User Registrations*: Bar chart tracking monthly user acquisition.
  - *Statement Uploads Velocity*: Ingestion volume per day.
- **3 Data Management Tables**:
  - *User Management*: Filter by Admin/User role, search by name or email, client-side pagination.
  - *Statement Uploads Tracking*: Filter by Processed/Pending/Failed status, file size formatting, search by file name or ID.
  - *Subscriptions Tracking*: Filter by Free/Pro/Enterprise tier, pricing stats, date range tracking.
- **Role-Based Authentication**: Admin login overlay with JWT token storage and role validation (`Role === 0` / `Admin`).

---

## 🔑 Default Admin Credentials

- **Email**: `admin@themar.ip`
- **Password**: `AdminPassword123!`

---

## 🚀 How to Run

1. Ensure the `ThemarIP.API` backend is running on `http://localhost:5000`.
2. Open `index.html` directly in any web browser, or serve using any HTTP server:
   ```bash
   npx serve .
   ```
3. Access the dashboard at `http://localhost:3000` or open `index.html` in browser.
