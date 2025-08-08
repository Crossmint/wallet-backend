// Root config for Flightcontrol UI
"$schema": "https://app.flightcontrol.dev/schema.json"
environments: [
    // Development mirrors the current JSON config
    ({
      id:   "development"
      name: "Development"
    } & #BaseEnv),

    ({
      id:   "staging"
      name: "Staging"
    } & #BaseEnv),

    // Production: example overrides (adjust as needed)
    // ({
    //   id:   "production"
    //   name: "Production"
    //   // Example: larger cluster and more app instances
    //   services: [
    //     (#WebServiceDefaults & { minInstances: 2, maxInstances: 4 }),
    //     (#RDSDefaults & { instanceSize: "db.t3.medium", storage: 50 }),
    //   ]
    // } & #BaseEnv),
]

#WebServiceDefaults: {
  id:                               "wallet-backend"
  name:                             "Wallets Backend API"
  type:                             "web"
  buildType:                        "docker"
  dockerfilePath:                   "Dockerfile"
  dockerContext:                    "."
  injectEnvVariablesInDockerfile:   false
  includeEnvVariablesInBuild:       false
  target: {
    type:                 "ecs-ec2"
    clusterInstanceSize:  "t3.medium"
    clusterMinInstances:  1
    clusterMaxInstances:  2
  }
  cpu:                              0.75
  memory:                           0.75
  minInstances:                     1
  maxInstances:                     1
  port:                             8001
  containerInsights:                true
  healthCheckPath:                  "/health"
  healthCheckGracePeriodSecs:       20
  envVariables: {
    DATABASE_URL: {
      fromService: {
        id:     "postgres-encrypted"
        value:  "dbConnectionString"
      }
    }
  }
  dependsOn: ["postgres-encrypted"]
}

#RDSDefaults: {
  id:                       "postgres-encrypted"
  name:                     "Postgres Database"
  type:                     "rds"
  instanceSize:             "db.t3.small"
  engine:                   "postgres"
  storage:                  20
  engineVersion:            "14"
  encryptionAtRest:         true
  private:                  true
  applyChangesImmediately:  false
}

#BaseEnv: {
  id:   string
  name: string
  region: "us-east-1"
  source: {
    branch: "main"
  }
  services: [#WebServiceDefaults, #RDSDefaults]
}

// no exported environments at top-level; use #Flightcontrol instead

