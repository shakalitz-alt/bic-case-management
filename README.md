# PNGICSA - BIC Case Management Platform

Official operational case management and Person of Interest (POI) tracking platform for the PNG Immigration & Citizenship Service Authority (PNGICSA) at the Bomana Centre (BIC).

---

## System Architecture

* **Frontend**: HTML5, Tailwind CSS, FontAwesome 6, Chart.js (Served via IIS on Port `8088`)
* **Backend**: Node.js, Express.js (Managed via PM2 on Port `3005`)
* **Database**: PostgreSQL 15 (`bic_casemanagement`)
* **Reverse Proxy**: IIS Application Request Routing (ARR) / URL Rewrite 2.1 (`/v1/*` -> `http://localhost:3005`)

---

## Development & Release Lifecycle Rules

### Versioning Strategy
This project follows **Semantic Versioning** (`MAJOR.MINOR.PATCH`):
* `MAJOR`: Non-backward-compatible database or API schema changes.
* `MINOR`: Backward-compatible new modules or features.
* `PATCH`: Bug fixes, layout corrections, and performance tweaks.

### Conventional Commit Standard
All Git commits must follow the conventional commit format:
* `feat:` New features for operators
* `fix:` Bug fixes or patch corrections
* `docs:` Documentation updates (`README.md`, `CHANGELOG.md`)
* `chore:` PM2, IIS, or environment setup changes

---

## Quick Startup Guide

### 1. Restart Backend Service (PM2)
```powershell
cd C:\Projects\bic-case-management\backend
pm2 start server.js --name "bic-api"
pm2 save