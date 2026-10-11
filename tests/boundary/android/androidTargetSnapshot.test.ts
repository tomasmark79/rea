import { createHash } from "node:crypto";
import {
  mkdir,
  readFile,
  readdir,
  stat,
  truncate,
  writeFile,
} from "node:fs/promises";
import { join } from "node:path";

import { expect, it } from "vitest";

import {
  snapshotAndroidEngine,
  snapshotAndroidTarget,
} from "../../../src/android/AndroidTargetSnapshot.js";
import { createTestTempDirectory } from "../../fixtures/temporaryDirectory.js";

it.each(["engine", "target"] as const)(
  "finishes copying and closing a real Android %s snapshot",
  async (kind) => {
    const root = await createTestTempDirectory("rea-android-snapshot-");
    const source = join(root, "source");
    const output = join(root, "snapshot");
    const bytes = Buffer.alloc(256 * 1024, 0x61);
    const sha256 = createHash("sha256").update(bytes).digest("hex");
    await writeFile(source, bytes);
    await mkdir(output);

    const result =
      kind === "engine"
        ? await snapshotAndroidEngine(
            source,
            sha256,
            output,
            "inspect_android_package",
          )
        : await snapshotAndroidTarget(
            source,
            sha256,
            output,
            "inspect_android_package",
          );

    const path = typeof result === "string" ? result : result.path;
    expect(await readFile(path)).toEqual(bytes);
    expect(await readFile(source)).toEqual(bytes);
  },
);

it.each(["engine", "target"] as const)(
  "closes and removes an Android %s snapshot after a digest mismatch",
  async (kind) => {
    const root = await createTestTempDirectory("rea-android-snapshot-");
    const source = join(root, "source");
    const output = join(root, "snapshot");
    await writeFile(source, "changed bytes");
    await mkdir(output);
    const snapshot =
      kind === "engine" ? snapshotAndroidEngine : snapshotAndroidTarget;

    await expect(
      snapshot(source, "0".repeat(64), output, "inspect_android_package"),
    ).rejects.toMatchObject({
      _tag:
        kind === "engine"
          ? "AnalysisCapabilityUnavailableError"
          : "AnalysisInputError",
    });
    expect(await readdir(output)).toEqual([]);
    expect(await readFile(source, "utf8")).toBe("changed bytes");
  },
);

it.skipIf(process.platform === "win32")(
  "cancels an in-flight APK snapshot and removes its partial output",
  async () => {
    const root = await createTestTempDirectory("rea-android-snapshot-cancel-");
    const source = join(root, "large.apk");
    const snapshot = join(root, "target.apk");
    await writeFile(source, "");
    // A sparse extent keeps fixture setup cheap while ensuring the copy cannot
    // finish before the test observes its first output bytes and aborts it.
    await truncate(source, 64 * 1024 * 1024 * 1024);

    const controller = new AbortController();
    const pending = snapshotAndroidTarget(
      source,
      "0".repeat(64),
      root,
      "inspect_android_package",
      controller.signal,
    );
    try {
      await expect
        .poll(
          () =>
            stat(snapshot).then(
              ({ size }) => size > 0,
              () => false,
            ),
          { timeout: 10_000, interval: 10 },
        )
        .toBe(true);
      controller.abort();
      await expect(pending).rejects.toMatchObject({ name: "AbortError" });
      await expect(stat(snapshot)).rejects.toMatchObject({ code: "ENOENT" });
    } finally {
      controller.abort();
      await pending.catch(() => undefined);
    }
  },
);
