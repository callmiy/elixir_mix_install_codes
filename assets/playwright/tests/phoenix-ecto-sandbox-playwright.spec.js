// @ts-check
const fs = require("fs");
const pathModule = require("path");
const { test: base, expect } = require("@playwright/test");

const test = base.extend({
  useSandbox: async ({ context }, use, testInfo) => {
    const sandboxIdFromPreviousTestRun = await getOrSetSandboxId(testInfo);

    if (sandboxIdFromPreviousTestRun) {
      await checkInDatabaseSandbox(context, sandboxIdFromPreviousTestRun);
    }

    const response = await context.request.post("/sandbox");
    const newSandboxId = (await response.body()).toString();

    await getOrSetSandboxId(testInfo, newSandboxId);

    context.setExtraHTTPHeaders({
      Sandbox: newSandboxId,
    });

    await use(newSandboxId);
  },
});

test("page 1", async ({ useSandbox, page }) => {
  await useSandbox;

  await page.goto("/");

  await expect(page.locator("body")).toContainText("Hello, World!");

  // await page.pause()
});

// ====================================================
// START utils
// ====================================================

const GENERATED_CODES_TEMP_DIR =
  "/home/kanmii/projects/elixir/ugo_single/assets/gen/tmp";

async function getOrSetSandboxId(testInfo, newSandboxId) {
  const testOutputDir = pathModule.basename(testInfo.outputDir);

  const sandboxIdFilename = pathModule.resolve(
    GENERATED_CODES_TEMP_DIR,
    `playwright-${testOutputDir}-sandbox`
  );

  if (!fs.existsSync(sandboxIdFilename)) {
    fs.writeFileSync(sandboxIdFilename, "");
  }

  if (newSandboxId) {
    // Set the ID
    fs.writeFileSync(sandboxIdFilename, newSandboxId);
    return newSandboxId;
  }

  // Get the ID
  return (
    await fs.promises.readFile(sandboxIdFilename, { encoding: "utf8" })
  ).trim();
}

async function checkInDatabaseSandbox(context, sandboxId) {
  return context.request.delete("/sandbox", {
    headers: { Sandbox: sandboxId },
    failOnStatusCode: false,
  });
}

// ====================================================
// END utils
// ====================================================
