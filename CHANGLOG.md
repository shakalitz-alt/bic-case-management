# Changelog

All notable changes to the PNGICSA Bomana Immigration Centre (BIC) Case Management platform will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-09-26

### Added
- **JWT User Authentication & RBAC**: Dual-account access model for `DUTY_MANAGER` (`admin.kila`) and `SYSTEM_ADMIN` (`sys.admin`) with bcrypt password hashing and 12-hour session tokens.
- **Form BIC-01 PDF Generator**: Dynamic PDF generation containing POI Identity, Risk Matrix, Compound Allocation, and embedded verification QR codes.
- **Operations & Analytics Console**: Real-time Chart.js visualizers for POI risk distribution, compound capacity tracking, and top intakes by nationality.
- **Compound Allocation Module**: Capacity summary tracking bar and expandable rosters detailing housed POIs per compound.
- **Legal Proceedings Tracking**: High Court case filing registry, stay-on-removal injunction indicators, and legal counsel tracking modal.
- **Deportation & Logistics Pipeline**: Removal dispatch tracking for scheduled departures, travel document (CTD) issuance, and flight routing.
- **Audit Logs & Diagnostics Grid**: Active monitoring for Database, PM2 Node.js process, and IIS reverse proxy status alongside historical operator audit logs.
- **Operational Alert Banner**: Live alert notification banner triggered by critical suicide watch or immediate medical attention flags.

### Fixed
- Fixed PostgreSQL `priority_level_enum` casting error during intake creation.
- Restored `Sync Live Feeds` event handlers and alert banner close actions.
- Synchronized frontend deployments between project repository and IIS web root (`C:\inetpub\wwwroot\bic-frontend`).