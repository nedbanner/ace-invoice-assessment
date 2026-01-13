function requireApiKey(req, res, next) {
  const provided = req.header("x-api-key");
  const expected = process.env.API_KEY;

  if (!provided || String(provided).trim().length === 0) {
    return res.status(401).json({ message: "Unauthorized" });
  }
  if (!expected || provided !== expected) {
    return res.status(401).json({ message: "Unauthorized" });
  }
  next();
}

module.exports = { requireApiKey };
