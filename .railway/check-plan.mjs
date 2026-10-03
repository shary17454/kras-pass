import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";
import { isDeepStrictEqual } from "node:util";

function require(condition, message) {
  if (!condition) throw new Error(message);
}

const resources = ["service.kras-pass", "volume.kras-pass-volume"];
const keys = ["ACCOUNT_DB_PATH", "APPLE_CLIENT_ID", "APPLE_KEY_ID", "APPLE_PRIVATE_KEY", "APPLE_TEAM_ID", "OWNER_EMAIL"];
const allowed = /^((build\.(builder|dockerfilePath))|(deploy\.(startCommand|healthcheckPath|healthcheckTimeout|restartPolicyType|restartPolicyMaxRetries))) \(/;

export function validatePlan(plan) {
  require(plan?.ok === true && plan.command === "plan", "Expected a successful read-only Railway plan.");
  const target = plan.currentEnvironment;
  require(target?.projectId === "eb193205-199c-4aab-8aff-1bb532dfb4a3" &&
    target.environmentId === "cb3cc392-8240-49a9-aeb6-e3894cace30b" &&
    target.environmentName === "production" && typeof target.configEtag === "string" && target.configEtag.length > 0,
  "Wrong target or missing environment revision.");
  require(Array.isArray(plan.diagnostics) && plan.diagnostics.length === 0, "Resolve plan diagnostics before applying.");
  const [current, desired] = [plan.currentGraph, plan.desiredGraph];
  for (const graph of [current, desired]) {
    require(Array.isArray(graph?.resources) && isDeepStrictEqual(graph.resources.map(r => r.address).sort(), resources),
      "Unexpected resources: import and review the complete environment again.");
  }
  const get = (graph, address) => graph.resources.find(r => r.address === address);
  const before = get(current, resources[0]);
  const after = get(desired, resources[0]);
  const source = { type: "github", repo: "shary17454/kras-pass", branch: "main", checkSuites: false };
  require(isDeepStrictEqual(before.source, source) && isDeepStrictEqual(after.source, source), "Repository source must remain unchanged.");
  for (const node of [before, after]) {
    require(isDeepStrictEqual(Object.keys(node.variables ?? {}).sort(), keys), "Variable keys differ from the reviewed import.");
    require(Object.values(node.variables).every(v => isDeepStrictEqual(v, { type: "preserve" })), "Never apply literal or changed variable values.");
  }
  require(isDeepStrictEqual(before.volumeAttachments, after.volumeAttachments) &&
    after.volumeAttachments?.["kras-pass-volume"]?.mountPath === "/data" &&
    after.volumeAttachments["kras-pass-volume"].volume === resources[1], "Persistent data attachment changed.");
  const diskBefore = get(current, resources[1]);
  const diskAfter = get(desired, resources[1]);
  require(isDeepStrictEqual(diskBefore, diskAfter) && diskAfter.config?.region === "ams" && diskAfter.config.sizeMB === 5000,
    "Persistent storage configuration changed.");
  require(isDeepStrictEqual(before.deploy?.multiRegionConfig, after.deploy?.multiRegionConfig) &&
    isDeepStrictEqual(after.deploy.multiRegionConfig, { ams: { numReplicas: 1 } }), "Replica placement changed.");
  require(isDeepStrictEqual(after.build, { builder: "DOCKERFILE", dockerfilePath: "/Dockerfile" }), "Missing Docker build configuration.");
  require(isDeepStrictEqual(after.deploy, {
    healthcheckPath: "/health", healthcheckTimeout: 100,
    multiRegionConfig: { ams: { numReplicas: 1 } },
    restartPolicyMaxRetries: 10, restartPolicyType: "ON_FAILURE", startCommand: "npm start",
  }), "Deployment settings differ from the reviewed migration.");
  require(Array.isArray(plan.changeSet?.changes), "Missing change set.");
  for (const change of plan.changeSet.changes) {
    require(change.kind === "resource.update" && change.severity === "safe" &&
      typeof change.summary === "string" && change.summary.startsWith("Update kras-pass ") &&
      Array.isArray(change.details) && change.details.length > 0 && change.details.every(d => typeof d === "string" && allowed.test(d)),
    "Refusing a destructive, unrelated or unreviewed change.");
  }
  return { project: target.projectId, environment: target.environmentId, safeUpdates: plan.changeSet.changes.length };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    if (process.argv.length !== 3) throw new Error("Usage: node .railway/check-plan.mjs PLAN_JSON");
    const result = validatePlan(JSON.parse(readFileSync(process.argv[2], "utf8")));
    console.log(JSON.stringify(result));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
