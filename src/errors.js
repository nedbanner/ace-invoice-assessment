class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}
function notFound(message = "Not Found") { return new HttpError(404, message); }
function badRequest(message = "Bad Request") { return new HttpError(400, message); }

module.exports = { HttpError, notFound, badRequest };
