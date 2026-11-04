import { describe, it, expect } from "vitest";
import { mkdtempSync, readFileSync, rmSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";

const __dirname = dirname(fileURLToPath(import.meta.url));
const rootDir = resolve(__dirname, "..");

describe("Dual Claude Code + OpenCode installer and plugin manifests", () => {
  it("ships valid .claude-plugin manifests and trello-update skill", () => {
    const pluginJson = JSON.parse(readFileSync(resolve(rootDir, ".claude-plugin/plugin.json"), "utf8"));
    expect(pluginJson.name).toBe("trello");
    expect(existsSync(resolve(rootDir, "skills/trello-update/SKILL.md"))).toBe(true);
  });

  it("installs into isolated HOME for both Claude Code and OpenCode", () => {
    const fakeHome = mkdtempSync(join(tmpdir(), "trello-install-test-"));
    try {
      execFileSync("bash", [resolve(rootDir, "install.sh")], {
        env: { ...process.env, HOME: fakeHome, TRELLO_SKIP_CLAUDE_CLI: "1" },
        stdio: "pipe",
      });

      expect(existsSync(join(fakeHome, ".claude", "skills", "trello-update", "SKILL.md"))).toBe(true);

      const ocJsonPath = join(fakeHome, ".config", "opencode", "opencode.json");
      expect(existsSync(ocJsonPath)).toBe(true);
      const ocCfg = JSON.parse(readFileSync(ocJsonPath, "utf8"));
      expect(ocCfg.mcp?.trello?.type).toBe("local");
      expect(ocCfg.mcp?.trello?.enabled).toBe(true);
      expect(ocCfg.mcp?.trello?.command?.[1]).toMatch(/dist\/index\.js$/);
      expect(ocCfg.skills?.paths).toContain(resolve(rootDir, "skills"));
    } finally {
      rmSync(fakeHome, { recursive: true, force: true });
    }
  });
});
