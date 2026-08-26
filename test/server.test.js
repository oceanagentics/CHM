const assert = require("node:assert/strict");
const { test } = require("node:test");

const { createApp } = require("../src/server");

async function withServer(fn) {
  const app = createApp();
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
