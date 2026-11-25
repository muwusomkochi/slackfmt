import { defineConfig } from "vitest/config";

export default defineConfig({ test: { name: "macos fixtures", include: ["Tests/reference.test.ts"] } });
