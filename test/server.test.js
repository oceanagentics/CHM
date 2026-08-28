const assert = require("node:assert/strict");
const { test } = require("node:test");

const { createApp } = require("../src/server");

async function withServer(fn, appOptions = {}) {
  const app = createApp(appOptions);
  const server = app.listen(0, "127.0.0.1");

  try {
    await new Promise((resolve, reject) => {
      server.once("listening", resolve);
      server.once("error", reject);
    });

    const { port } = server.address();
    await fn(`http://127.0.0.1:${port}`);
  } finally {
    if (server.listening) {
      await new Promise((resolve, reject) => {
        server.close((error) => (error ? reject(error) : resolve()));
      });
    }
  }
}

test("serves the CHM portal", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/`);
    const body = await response.text();

    assert.equal(response.status, 200);
    assert.match(response.headers.get("content-type"), /text\/html/);
    assert.match(response.headers.get("content-security-policy"), /default-src 'self'/);
    assert.equal(response.headers.get("x-content-type-options"), "nosniff");
    assert.equal(response.headers.get("x-frame-options"), "SAMEORIGIN");
    assert.match(body, /<h1>CHM<\/h1>/);
    assert.match(body, /href="\/explorer"/);
  });
});

test("redirects /login to the portal after IAP", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/login`, { redirect: "manual" });

    assert.equal(response.status, 302);
    assert.equal(response.headers.get("location"), "/");
  });
});

test("serves a health endpoint", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/healthz`);

    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { status: "ok" });
  });
});

test("fails closed in production when IAP audience is missing", () => {
  const previousNodeEnv = process.env.NODE_ENV;
  const previousIapAudience = process.env.IAP_JWT_AUDIENCE;
  process.env.NODE_ENV = "production";
  delete process.env.IAP_JWT_AUDIENCE;

  try {
    assert.throws(() => createApp(), /IAP_JWT_AUDIENCE is required in production/);
  } finally {
    if (previousNodeEnv === undefined) {
      delete process.env.NODE_ENV;
    } else {
      process.env.NODE_ENV = previousNodeEnv;
    }

    if (previousIapAudience === undefined) {
      delete process.env.IAP_JWT_AUDIENCE;
    } else {
      process.env.IAP_JWT_AUDIENCE = previousIapAudience;
    }
  }
});

test("keeps /healthz available when IAP audience is configured", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/healthz`);

    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { status: "ok" });
  }, {
    iapAudience: "/projects/288836337031/global/backendServices/1981640158971360804",
  });
});

test("rejects missing IAP assertions when IAP audience is configured", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/`);

    assert.equal(response.status, 401);
    assert.deepEqual(await response.json(), { error: "missing_iap_assertion" });
  }, {
    iapAudience: "/projects/288836337031/global/backendServices/1981640158971360804",
  });
});

test("accepts valid Ocean Agentics IAP assertions", async () => {
  const iapAudience = "/projects/288836337031/global/backendServices/1981640158971360804";

  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/`, {
      headers: {
        "x-goog-iap-jwt-assertion": "valid.jwt",
      },
    });

    assert.equal(response.status, 200);
  }, {
    iapAudience,
    validateIapAssertion: async (assertion, expectedAudience) => {
      assert.equal(assertion, "valid.jwt");
      assert.equal(expectedAudience, iapAudience);

      return {
        email: "danny@oceanagentics.com",
        hd: "oceanagentics.com",
        sub: "accounts.google.com:123",
      };
    },
  });
});

test("returns a clear 404 when Explorer API proxy is not configured", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/explorer/nodes`);

    assert.equal(response.status, 404);
    assert.deepEqual(await response.json(), { error: "explorer_api_not_configured" });
  });
});

test("rejects IAP assertions outside Ocean Agentics", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/`, {
      headers: {
        "x-goog-iap-jwt-assertion": "valid.jwt",
      },
    });

    assert.equal(response.status, 403);
    assert.deepEqual(await response.json(), { error: "forbidden" });
  }, {
    iapAudience: "/projects/288836337031/global/backendServices/1981640158971360804",
    validateIapAssertion: async () => ({
      email: "person@example.com",
      hd: "example.com",
      sub: "accounts.google.com:456",
    }),
  });
});

test("returns a clear 404 for deferred routes", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/explorer`);

    assert.equal(response.status, 404);
    assert.deepEqual(await response.json(), {
      error: "not_found",
      path: "/explorer",
    });
  });
});
