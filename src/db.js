const sql = require("mssql");

function getConfig() {
  const encrypt = String(process.env.SQL_ENCRYPT || "false").toLowerCase() === "true";
  return {
    server: process.env.SQL_SERVER,
    port: Number(process.env.SQL_PORT || 1433),
    database: process.env.SQL_DATABASE,
    user: process.env.SQL_USER,
    password: process.env.SQL_PASSWORD,
    options: {
      encrypt,
      trustServerCertificate: true
    },
    pool: {
      max: 10,
      min: 0,
      idleTimeoutMillis: 30000
    }
  };
}

let poolPromise;

async function getPool() {
  if (!poolPromise) {
    poolPromise = sql.connect(getConfig());
  }
  return poolPromise;
}

module.exports = { sql, getPool };
