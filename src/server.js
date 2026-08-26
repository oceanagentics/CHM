const express = require("express");

function createApp() {
  const app = express();

  app.disable("x-powered-by");
  app.set("trust proxy", true);

  app.get("/", (_req, res) => {
    res.type("html").send(`<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>CHM</title>
  <style>
    :root {
      color-scheme: light;
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: #f7f8fa;
      color: #17202a;
    }

    body {
      margin: 0;
      min-height: 100vh;
      display: grid;
      place-items: center;
    }

    main {
      width: min(720px, calc(100vw - 32px));
    }

    h1 {
      margin: 0 0 12px;
      font-size: clamp(2rem, 4vw, 3.25rem);
      line-height: 1;
    }

    p {
      margin: 0 0 24px;
      color: #516173;
      font-size: 1rem;
      line-height: 1.55;
    }

    a {
      display: inline-flex;
      align-items: center;
      min-height: 44px;
      padding: 0 16px;
      border: 1px solid #b9c3cf;
      border-radius: 6px;
      color: #17202a;
      font-weight: 600;
      text-decoration: none;
      background: #ffffff;
    }

    a:focus,
    a:hover {
      border-color: #4d6b8a;
    }
  </style>
</head>
<body>
  <main>
    <h1>CHM</h1>
    <p>Authenticated portal for Ocean Agentics CHM applications.</p>
    <a href="/explorer">Open Explorer</a>
  </main>
</body>
</html>`);
  });

  app.get("/login", (_req, res) => {
    res.redirect(302, "/");
  });

  app.get("/healthz", (_req, res) => {
    res.status(200).json({ status: "ok" });
  });

  app.use((req, res) => {
    res.status(404).json({
      error: "not_found",
      path: req.path,
    });
  });

  return app;
}

function start() {
  const port = Number.parseInt(process.env.PORT || "8080", 10);
  const host = process.env.HOST || "0.0.0.0";
  const app = createApp();

  return app.listen(port, host, () => {
    console.log(`CHM listening on http://${host}:${port}`);
  });
}

if (require.main === module) {
  start();
}

module.exports = { createApp, start };
