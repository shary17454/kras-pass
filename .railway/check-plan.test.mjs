import assert from "node:assert/strict";
import { test } from "node:test";
import { createRailwayContext } from "railway/iac";
import define from "./railway.ts";
import { validatePlan } from "./check-plan.mjs";

const api = graph => graph.resources.find(resource => resource.address === "service.kras-pass");
const disk = graph => graph.resources.find(resource => resource.address === "volume.kras-pass-volume");

function fixture() {
  const target = { projectId: "eb193205-199c-4aab-8aff-1bb532dfb4a3", environmentId: "cb3cc392-8240-49a9-aeb6-e3894cace30b", environment: "production", environmentName: "production", configEtag: "reviewed-revision" };
  const desired = { resources: JSON.parse(JSON.stringify(define(createRailwayContext(target)).resources)) };
  const current = structuredClone(desired);
  api(current).build = { builder: "RAILPACK" };
  api(current).deploy = { multiRegionConfig: { ams: { numReplicas: 1 } } };
  return { ok: true, command: "plan", currentEnvironment: target, currentGraph: current, desiredGraph: desired, diagnostics: [], changeSet: { changes: [{ kind: "resource.update", severity: "safe", summary: "Update kras-pass deploy.healthcheckPath", details: ["deploy.healthcheckPath (null → \"/health\")"] }] } };
}

test("accepts only the reviewed non-destructive deployment settings", () => {
  assert.equal(validatePlan(fixture()).safeUpdates, 1);
});

for (const [name, mutate] of [
  ["wrong environment", p => { p.currentEnvironment.environmentId = "other"; }],
  ["missing revision", p => { delete p.currentEnvironment.configEtag; }],
  ["failed plan", p => { p.ok = false; }],
  ["diagnostic", p => { p.diagnostics.push({ severity: "warning" }); }],
  ["unmanaged extra resource", p => { p.currentGraph.resources.push({ address: "service.other" }); }],
  ["wrong branch", p => { api(p.desiredGraph).source.branch = "feature"; }],
  ["literal secret", p => { api(p.desiredGraph).variables.APPLE_PRIVATE_KEY = { type: "literal", value: "fake" }; }],
  ["missing variable", p => { delete api(p.desiredGraph).variables.OWNER_EMAIL; }],
  ["volume detachment", p => { api(p.desiredGraph).volumeAttachments = {}; }],
  ["storage shrink", p => { disk(p.desiredGraph).config.sizeMB = 1000; }],
  ["replica move", p => { api(p.desiredGraph).deploy.multiRegionConfig = { iad: { numReplicas: 1 } }; }],
  ["missing health check", p => { delete api(p.desiredGraph).deploy.healthcheckPath; }],
  ["destructive change", p => { p.changeSet.changes[0].severity = "destructive"; }],
  ["resource removal", p => { p.changeSet.changes[0].kind = "resource.delete"; }],
  ["unrelated update", p => { p.changeSet.changes[0].summary = "Update other-service deploy.healthcheckPath"; }],
  ["variable update", p => { p.changeSet.changes[0].details = ["variables.OWNER_EMAIL (changed)"]; }],
]) {
  test(`rejects ${name}`, () => {
    const plan = fixture();
    mutate(plan);
    assert.throws(() => validatePlan(plan));
  });
}
