const express = require("express");
const router = express.Router();

router.get("/hello", (req, res) => {
  // Match Postman collection description
  res.json("API Online & Available...");
});

module.exports = router;
