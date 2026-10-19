import { configDefaults, defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    include: ["test/*.js"],
    expect: {
      requireAssertions: true,
    },
    forceRerunTriggers: [
      ...configDefaults.forceRerunTriggers,
      "**/libs/**",
      "**/test/testdata/**",
    ],
  },
});
