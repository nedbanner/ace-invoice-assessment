# ACE Parking — Invoice API (SQL Server + Node.js)

This repo implements the ACE Parking developer assessment:
- SQL Server schema + seed data for Customers, Products, Orders, OrderItems
- Stored procedures for creating and retrieving invoices
- REST API (Node.js + Express) with `x-api-key` authentication

## Quick start (Docker — recommended)

### 1) Install Docker Desktop
- Windows/Mac: Docker Desktop

### 2) Run SQL Server + init + API
From the repo root:

```bash
cd docker
docker compose up -d --build
```

Wait ~30-60s for SQL Server to be healthy and the init script to run.

### 3) Smoke test
```bash
# Health check (no auth required)
curl http://localhost:5001/api/public/hello

# Auth required
curl http://localhost:5001/api/product/viewall

# With auth
curl -H "x-api-key: DEV-ACE-KEY" http://localhost:5001/api/product/viewall
curl -H "x-api-key: DEV-ACE-KEY" http://localhost:5001/api/customer/viewall
curl -H "x-api-key: DEV-ACE-KEY" http://localhost:5001/api/order/details/5
```

## Run locally (without Docker)

### 1) Create `.env`
Copy `.env.example` to `.env` and set SQL connection values.

### 2) Install deps + run
```bash
npm install
npm run start
```

API runs at `http://localhost:5001`.

## API Key Auth
All endpoints except `/api/public/hello` require a header:

- `x-api-key: DEV-ACE-KEY` (configure via `API_KEY` env var)

Returns 401 if missing or invalid.

## Endpoints
- `GET /api/public/hello` (no auth)
- `GET /api/customer/viewall` (auth)
- `GET /api/product/viewall` (auth)
- `GET /api/order/viewall` (auth)
- `GET /api/order/vieworderdetail` (auth)
- `GET /api/order/details/:invoiceNumber` (auth)
- `POST /api/order/new` (auth)

### POST /api/order/new body
```json
{
  "invoiceData": {
    "invoiceDate": "2024-12-20T14:30:00Z",
    "customerId": "AA5FD07A-05D6-460F-B8E3-6A09142F9D71"
  },
  "products": [
    { "productId": "26812D43-CEE0-4413-9A1B-0B2EABF7E92C", "quantity": 2 },
    { "productId": "3C85F645-CE57-43A8-B192-7F46F8BBC273", "quantity": 5 }
  ]
}
```

Response:
```json
{ "invoiceNumber": 6 }
```

## Database
Docker init script is in `docker/init.sql` and also copied to `database/init.sql`.

Seeded data includes an invoice with `invoiceNumber = 5` that matches the provided example.

## Postman
Import:
- `examples/Ace-Recruiting-Test-Example.postman_collection.json`
- (optional) `examples/local.postman_environment.json`
