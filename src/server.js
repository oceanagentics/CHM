const express = require("express");
const helmet = require("helmet");
const { OAuth2Client } = require("google-auth-library");

const IAP_HEADER = "x-goog-iap-jwt-assertion";
const IAP_ISSUER = "https://cloud.google.com/iap";
const OCEAN_AGENTICS_DOMAIN = "oceanagentics.com";
const ADMIN_HINT_COOKIE_NAME = "chm_admin_hint";
const DEFAULT_ADMIN_HINT_EMAILS = ["danny@oceanagentics.com"];
const iapClient = new OAuth2Client();

let cachedIapKeys = null;

async function getIapPublicKeys() {
  const now = Date.now();

  if (!cachedIapKeys || cachedIapKeys.expiresAt <= now) {
    const response = await iapClient.getIapPublicKeys();
    cachedIapKeys = {
      pubkeys: response.pubkeys,
      expiresAt: now + 5 * 60 * 1000,
    };
  }

  return cachedIapKeys.pubkeys;
}

async function validateIapAssertion(assertion, expectedAudience) {
  const pubkeys = await getIapPublicKeys();
  const ticket = await iapClient.verifySignedJwtWithCertsAsync(
    assertion,
    pubkeys,
    expectedAudience,
    [IAP_ISSUER],
  );

  return ticket.getPayload();
}

function getOceanAgenticsUser(payload) {
  const email = typeof payload?.email === "string" ? payload.email.toLowerCase() : "";
  const hostedDomain = typeof payload?.hd === "string" ? payload.hd.toLowerCase() : "";
  const subject = typeof payload?.sub === "string" ? payload.sub : "";

  if (!subject || hostedDomain !== OCEAN_AGENTICS_DOMAIN || !email.endsWith(`@${OCEAN_AGENTICS_DOMAIN}`)) {
    return null;
  }

  return {
    email,
    hostedDomain,
    subject,
  };
}

function requireIap(options = {}) {
  const expectedAudience = options.iapAudience || process.env.IAP_JWT_AUDIENCE;
  const validateAssertion = options.validateIapAssertion || validateIapAssertion;

  if (!expectedAudience && process.env.NODE_ENV === "production") {
    throw new Error("IAP_JWT_AUDIENCE is required in production");
  }

  return async (req, res, next) => {
    if (req.path === "/healthz") {
      return next();
    }

    if (!expectedAudience) {
      return next();
    }

    const assertion = req.get(IAP_HEADER);

    if (!assertion) {
      return res.status(401).json({ error: "missing_iap_assertion" });
    }

    try {
      const payload = await validateAssertion(assertion, expectedAudience);
      const user = getOceanAgenticsUser(payload);

      if (!user) {
        return res.status(403).json({ error: "forbidden" });
      }

      req.iapUser = user;
      return next();
    } catch (error) {
      console.warn("IAP JWT validation failed", { message: error.message });
      return res.status(401).json({ error: "invalid_iap_assertion" });
    }
  };
}

function readEmailList(value) {
  if (Array.isArray(value)) {
    return value.flatMap(readEmailList);
  }

  if (typeof value !== "string") {
    return [];
  }

  return value
    .split(",")
    .map((email) => email.trim().toLowerCase())
    .filter(Boolean);
}

function adminHintEmails(options = {}) {
  const configuredEmails =
    options.adminHintEmails ?? process.env.CHM_ADMIN_HINT_EMAILS;
  const emails = readEmailList(configuredEmails);
  return new Set(emails.length > 0 ? emails : DEFAULT_ADMIN_HINT_EMAILS);
}

function setAdminHintCookie(adminEmails) {
  return (req, res, next) => {
    if (req.iapUser?.email && adminEmails.has(req.iapUser.email)) {
      res.cookie(ADMIN_HINT_COOKIE_NAME, "1", {
        maxAge: 24 * 60 * 60 * 1000,
        path: "/",
        sameSite: "lax",
        secure: process.env.NODE_ENV === "production",
      });
    }

    next();
  };
}

function createApp(options = {}) {
  const app = express();
  const hintAdminEmails = adminHintEmails(options);

  app.disable("x-powered-by");
  app.set("trust proxy", true);
  app.use(helmet());
  app.use(express.json({ limit: "2mb" }));
  app.use(requireIap(options));
  app.use(setAdminHintCookie(hintAdminEmails));

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
    <a href="/explorer/admin">Open Explorer</a>
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
