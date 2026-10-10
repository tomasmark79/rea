import { createHash } from "node:crypto";
import { mkdir, readFile, readdir, writeFile } from "node:fs/promises";
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
