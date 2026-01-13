require("dotenv").config();
const express = require("express");
const { requireApiKey } = require("./auth");
const { HttpError } = require("./errors");

const publicRoutes = require("./routes/public");
const customerRoutes = require("./routes/customers");
const productRoutes = require("./routes/products");
const orderRoutes = require("./routes/orders");

const app = express();
app.use(express.json());

// Public
app.use("/api/public", publicRoutes);

// Protected
app.use("/api/customer", requireApiKey, customerRoutes);
app.use("/api/product", requireApiKey, productRoutes);
app.use("/api/order", requireApiKey, orderRoutes);

// 404
app.use((req, res) => {
  res.status(404).json({ message: "Not Found" });
});

// Error handler (don’t leak internals)
app.use((err, req, res, next) => {
  if (err instanceof HttpError) {
    return res.status(err.status).json({ message: err.message });
  }
  console.error("Unhandled error:", err);
  res.status(500).json({ message: "Internal Server Error" });
});

const port = Number(process.env.PORT || 5001);
const host = "0.0.0.0";
app.listen(port, host, () => {
  console.log(`API listening on http://${host}:${port}`);
});
