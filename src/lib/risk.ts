export type RiskAsset = Pick<{ criticality: number; status: string }, "criticality" | "status">;
export type RiskObservation = Pick<{
  vibration_mm_s: number | null;
  temperature_c: number | null;
  pressure_bar: number | null;
}, "vibration_mm_s" | "temperature_c" | "pressure_bar">;

export function scoreAsset(asset: RiskAsset, observation?: RiskObservation) {
  if (!observation) return { score: null as number | null, factors: ["No condition reading yet"] };
  let score = (6 - asset.criticality) * 4;
  const factors: string[] = [];
  if (observation.vibration_mm_s != null) {
    if (observation.vibration_mm_s >= 7.1) { score += 35; factors.push("Vibration at or above high screening band"); }
    else if (observation.vibration_mm_s >= 4.5) { score += 22; factors.push("Vibration in elevated screening band"); }
    else if (observation.vibration_mm_s >= 2.8) { score += 10; factors.push("Vibration above baseline band"); }
  }
  if (observation.temperature_c != null) {
    if (observation.temperature_c >= 90) { score += 30; factors.push("Temperature at or above high screening band"); }
    else if (observation.temperature_c >= 75) { score += 18; factors.push("Temperature in elevated screening band"); }
    else if (observation.temperature_c >= 60) { score += 8; factors.push("Temperature above baseline band"); }
  }
  if (observation.pressure_bar != null && observation.pressure_bar <= 0) { score += 16; factors.push("Pressure reading is non-positive"); }
  if (asset.status === "offline") { score += 20; factors.push("Asset is marked offline"); }
  score = Math.max(0, Math.min(100, Math.round(score)));
  if (!factors.length) factors.push("No entered measurement exceeds the generic screening bands");
  return { score, factors };
}
