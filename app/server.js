"use strict";
const express = require("express");
const exphbs = require("express-handlebars");
const db = require("./models");

const PORT = process.env.PORT || 8080;
const app = express();

app.use(express.static("public"));
app.use(express.urlencoded({ extended: true }));
app.use(express.json());

app.engine("handlebars", exphbs({ defaultLayout: "main" }));
app.set("view engine", "handlebars");

// Structured JSON request logger
app.use((req, res, next) => {
  const start = Date.now();
  res.on("finish", () => {
    console.log(JSON.stringify({
      timestamp: new Date().toISOString(),
      level:     res.statusCode >= 500 ? "error" : res.statusCode >= 400 ? "warn" : "info",
      method:    req.method,
      path:      req.path,
      status:    res.statusCode,
      duration:  `${Date.now() - start}ms`,
      ip:        req.headers["x-forwarded-for"] || req.socket.remoteAddress
    }));
  });
  next();
});

// Health check endpoint
app.get("/health", async (req, res) => {
  try {
    await db.sequelize.authenticate();
    res.status(200).json({ status: "ok", db: "connected" });
  } catch (err) {
    res.status(503).json({ status: "error", db: "unreachable" });
  }
});

require("./routes/cart-api-routes")(app);
console.log("going to html route");
app.use("/", require("./routes/html-routes"));
app.use("/cart", require("./routes/html-routes"));
app.use("/gallery", require("./routes/html-routes"));

db.sequelize.sync().then(function () {
  app.listen(PORT, function () {
    console.log(JSON.stringify({
      timestamp: new Date().toISOString(),
      level: "info",
      message: `App listening on PORT ${PORT}`
    }));
  });
});
