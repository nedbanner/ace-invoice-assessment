const express = require("express");
const router = express.Router();
const { sql, getPool } = require("../db");
const { badRequest, notFound } = require("../errors");
const { shapeOrderSummary, shapeOrderDetails } = require("../shape");

/**
 * GET /api/order/viewall
 * Summary list of all orders (no line item details)
 */
router.get("/viewall", async (req, res, next) => {
  try {
    const pool = await getPool();
    const r = await pool.request().execute("dbo.usp_GetAllOrdersSummary");
    res.json(r.recordset.map(shapeOrderSummary));
  } catch (e) {
    next(e);
  }
});

/**
 * GET /api/order/vieworderdetail
 * All orders with customer + line items
 */
router.get("/vieworderdetail", async (req, res, next) => {
  try {
    const pool = await getPool();
    const r = await pool.request().execute("dbo.usp_GetAllOrdersWithDetails");

    const orders = r.recordsets?.[0] || [];
    const customers = r.recordsets?.[1] || [];
    const lineItems = r.recordsets?.[2] || [];

    const customerById = new Map(customers.map(c => [String(c.CustomerId).toLowerCase(), c]));
    const itemsByInvoice = new Map();
    for (const li of lineItems) {
      const key = li.InvoiceNumber;
      if (!itemsByInvoice.has(key)) itemsByInvoice.set(key, []);
      itemsByInvoice.get(key).push(li);
    }

    const result = [];
    for (const o of orders) {
      const cust = customerById.get(String(o.CustomerId).toLowerCase());
      if (!cust) continue;
      const items = itemsByInvoice.get(o.InvoiceNumber) || [];
      result.push(shapeOrderDetails(o, cust, items));
    }

    res.json(result);
  } catch (e) {
    next(e);
  }
});

/**
 * GET /api/order/details/:invoiceNumber
 */
router.get("/details/:invoiceNumber", async (req, res, next) => {
  try {
    const invoiceNumber = Number(req.params.invoiceNumber);
    if (!Number.isInteger(invoiceNumber) || invoiceNumber <= 0) {
      throw badRequest("invoiceNumber must be a positive integer");
    }

    const pool = await getPool();
    const r = await pool
      .request()
      .input("InvoiceNumber", sql.Int, invoiceNumber)
      .execute("dbo.usp_GetOrderDetails");

    const orderRow = r.recordsets?.[0]?.[0];
    const customerRow = r.recordsets?.[1]?.[0];
    const lineItems = r.recordsets?.[2] || [];

    if (!orderRow || !customerRow) throw notFound("Order not found");

    res.json(shapeOrderDetails(orderRow, customerRow, lineItems));
  } catch (e) {
    next(e);
  }
});

/**
 * POST /api/order/new
 * Body matches examples/post-order-request.json:
 * {
 *   "invoiceData": { "invoiceDate": "2024-12-20T14:30:00Z", "customerId": "GUID" },
 *   "products": [ { "productId": "GUID", "quantity": 2 }, ... ]
 * }
 */
router.post("/new", async (req, res, next) => {
  try {
    const body = req.body || {};
    const invoiceData = body.invoiceData || {};
    const products = Array.isArray(body.products) ? body.products : [];

    const invoiceDateRaw = String(invoiceData.invoiceDate || "").trim();
    const customerId = String(invoiceData.customerId || "").trim();

    if (!invoiceDateRaw) throw badRequest("invoiceData.invoiceDate is required");
    if (!customerId) throw badRequest("invoiceData.customerId is required");
    if (products.length === 0) throw badRequest("products must be a non-empty array");

    const invoiceDate = new Date(invoiceDateRaw);
    if (Number.isNaN(invoiceDate.getTime())) throw badRequest("invoiceData.invoiceDate must be a valid ISO date");

    for (const [i, p] of products.entries()) {
      const pid = String(p.productId || "").trim();
      const qty = Number(p.quantity);
      if (!pid) throw badRequest(`products[${i}].productId is required`);
      if (!Number.isInteger(qty) || qty <= 0) throw badRequest(`products[${i}].quantity must be a positive integer`);
    }

    const pool = await getPool();

    const tvp = new sql.Table("dbo.NewOrderProductType");
    tvp.columns.add("ProductId", sql.UniqueIdentifier, { nullable: false });
    tvp.columns.add("Quantity", sql.Int, { nullable: false });
    for (const p of products) {
      tvp.rows.add(p.productId, Number(p.quantity));
    }

    const createResult = await pool
      .request()
      .input("InvoiceDate", sql.DateTime2(0), invoiceDate)
      .input("CustomerId", sql.UniqueIdentifier, customerId)
      .input("Products", tvp)
      .execute("dbo.usp_CreateOrder");

    const invoiceNumber = createResult.recordset?.[0]?.invoiceNumber;

    res.status(201).json({ invoiceNumber });
  } catch (e) {
    // translate business validation throws -> 400
    if (typeof e?.number === "number" && (e.number === 50001 || e.number === 50002)) {
      return res.status(400).json({ message: e.message });
    }
    next(e);
  }
});

module.exports = router;
