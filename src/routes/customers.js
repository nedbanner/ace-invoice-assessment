const express = require("express");
const router = express.Router();
const { getPool } = require("../db");
const { shapeCustomer } = require("../shape");

router.get("/viewall", async (req, res, next) => {
  try {
    const pool = await getPool();
    const result = await pool.request().execute("dbo.usp_GetAllCustomers");
    res.json(result.recordset.map(shapeCustomer));
  } catch (e) {
    next(e);
  }
});

module.exports = router;
