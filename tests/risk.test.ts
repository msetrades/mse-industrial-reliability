import assert from "node:assert/strict";
import test from "node:test";
import { scoreAsset } from "../src/lib/risk.ts";

test("risk screening explains elevated readings and offline status", () => {
  const result = scoreAsset({ criticality: 5, status: "offline" }, { vibration_mm_s: 7.1, temperature_c: 90, pressure_bar: 2 });
  assert.equal(result.score, 89);
  assert.equal(result.factors.length, 3);
});

test("risk score is absent without readings and capped at 100", () => {
  assert.equal(scoreAsset({ criticality: 3, status: "active" }).score, null);
  assert.equal(scoreAsset({ criticality: 1, status: "offline" }, { vibration_mm_s: 12, temperature_c: 120, pressure_bar: -1 }).score, 100);
});
