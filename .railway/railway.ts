import { defineRailway, github, preserve, project, service, volume } from "railway/iac";

export default defineRailway((ctx) => {
  if (ctx.projectId !== "eb193205-199c-4aab-8aff-1bb532dfb4a3" ||
      ctx.environmentId !== "cb3cc392-8240-49a9-aeb6-e3894cace30b" ||
      ctx.environment !== "production") {
    throw new Error("This configuration is restricted to KRAS PASS production.");
  }
  const krasPassVolume = volume("kras-pass-volume", { alerts: { usage: { "100": {}, "80": {}, "95": {} } }, allowOnlineResize: true, region: "ams", sizeMB: 5000 });
  const krasPass = service("kras-pass", {
    source: github("shary17454/kras-pass", { branch: "main", checkSuites: false }),
    build: { builder: "DOCKERFILE", dockerfilePath: "/Dockerfile" },
    deploy: { restartPolicyType: "ON_FAILURE", restartPolicyMaxRetries: 10 },
    start: "npm start",
    healthcheck: "/health",
    healthcheckTimeout: 100,
    replicas: { "ams": 1 },
    volumeMounts: { "/data": krasPassVolume },
    env: { ACCOUNT_DB_PATH: preserve(), APPLE_CLIENT_ID: preserve(), APPLE_KEY_ID: preserve(), APPLE_PRIVATE_KEY: preserve(), APPLE_TEAM_ID: preserve(), OWNER_EMAIL: preserve() },
  });

  return project("كراس باس", {
    resources: [krasPass, krasPassVolume],
  });
});
