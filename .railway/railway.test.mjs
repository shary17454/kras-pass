import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { createRailwayContext } from "railway/iac";
import define from "./railway.ts";

const production = {
  projectId: "eb193205-199c-4aab-8aff-1bb532dfb4a3",
  environmentId: "cb3cc392-8240-49a9-aeb6-e3894cace30b",
  environment: "production",
};
const spec = () => define(createRailwayContext(production));
const api = () => spec().resources.find(resource => resource.address === "service.kras-pass");

test("only the intended production target can be evaluated", () => {
  for (const wrong of [
    {},
    { ...production, projectId: "another-project" },
    { ...production, environmentId: "another-environment" },
    { ...production, environment: "staging" },
  ]) {
    assert.throws(() => define(createRailwayContext(wrong)), /restricted/);
  }
  assert.equal(spec().resources.length, 2);
});

test("SDK preserves every legacy deployment setting", () => {
  const legacy = JSON.parse(readFileSync(new URL("./legacy-config.json", import.meta.url)));
  const service = api();
  assert.equal(service.build.builder, legacy.build.builder);
  assert.equal(service.build.dockerfilePath, "/" + legacy.build.dockerfilePath);
  for (const key of ["startCommand", "healthcheckPath", "healthcheckTimeout", "restartPolicyType", "restartPolicyMaxRetries"]) {
    assert.equal(service.deploy[key], legacy.deploy[key], key);
  }
});

test("repository branch, replica location and data attachment stay unchanged", () => {
  const service = api();
  assert.deepEqual(service.source, { type: "github", repo: "shary17454/kras-pass", branch: "main", checkSuites: false });
  assert.deepEqual(service.deploy.multiRegionConfig, { ams: { numReplicas: 1 } });
  assert.equal(service.volumeAttachments["kras-pass-volume"].mountPath, "/data");
  assert.equal(service.volumeAttachments["kras-pass-volume"].volume, "volume.kras-pass-volume");
});

test("existing secrets remain Railway-managed, never literal values", () => {
  const variables = api().variables;
  assert.deepEqual(Object.keys(variables).sort(), ["ACCOUNT_DB_PATH", "APPLE_CLIENT_ID", "APPLE_KEY_ID", "APPLE_PRIVATE_KEY", "APPLE_TEAM_ID", "OWNER_EMAIL"]);
  for (const value of Object.values(variables)) assert.deepEqual(value, { type: "preserve" });
});

test("persistent storage size, region and usage alerts are retained", () => {
  const data = spec().resources.find(resource => resource.address === "volume.kras-pass-volume");
  assert.equal(data.config.sizeMB, 5000);
  assert.equal(data.config.region, "ams");
  assert.equal(data.config.allowOnlineResize, true);
  assert.deepEqual(data.config.alerts.usage, { "80": {}, "95": {}, "100": {} });
});
