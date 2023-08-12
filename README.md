# jenkins-job-trigger-action

Triggers Jenkins Jobs from GitHub actions

This action allows to trigger a job on Jenkins and get the build result.

### Inputs

- `jenkins_url`: **required** Jenkins instance URL
- `jenkins_user`: **required** User name used for authentication
- `jenkins_token`: **required** Jenkins API token that belongs to jenkins_user
- `job_name`: **required** for jobs stored in a folder use `{folder-name}/job/{job-name}`
- `jenkins_client_id`: **required** Jenkins Client ID used with IAP
- `jenkins_sa_credentials`: **required** Jenkins service account credentials to use with IAP
- `gcr_account_key`: **required** Account key to connect to GAR
- `job_params`: Valid JSON with key-value params passed to the job
- `job_timeout`: Number of seconds to wait for the action to finish (Default 30)
- `async`: Set to true if you want to just trigger the job and dont wait for it to complete (Default false)

**NOTE**: As of version 2.0.0 the `proxy` input has been removed and other required inputs have been added like: `jenkins_client_id`, `jenkins_sa_credentials` and `gcr_account_key`.

The `jenkins_client_id` is different for each jenkins server, i.e: for `jenkins-build.toptal.net`, its secrets client ID is `JENKINS_BUILD_CLIENT_ID`, and son on.

### Outputs

- `jenkins_job_url`: jenkins build URL if the scheduled job starts executing within given `job_timeout`

### Usage

```
name: Your GHA
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  your_job_name:
    name: Trigger Jenkins Job
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: GSM Secrets
        id: "secrets_manager"
        uses: toptal/actions/gsm-secrets@main
        with:
          workload_identity_provider: projects/858873486241/locations/global/workloadIdentityPools/gha-pool/providers/github-com
          service_account: gha-<repo_name>@toptal-ci.iam.gserviceaccount.com
          secrets_name: |-
            GCR_ACCOUNT_KEY:toptal-ci/GCR_ACCOUNT_KEY
            JENKINS_BUILD_URL:toptal-ci/JENKINS_BUILD_URL
            JENKINS_CLIENT_ID:toptal-ci/JENKINS_BUILD_CLIENT_ID
            JENKINS_SA_CREDENTIALS:toptal-ci/JENKINS_SA_CREDENTIALS
            TOPTAL_TRIGGERBOT_USERNAME:toptal-ci/TOPTAL_TRIGGERBOT_USERNAME
            TOPTAL_TRIGGERBOT_BUILD_TOKEN:toptal-ci/TOPTAL_TRIGGERBOT_BUILD_TOKEN

      - name: Parse secrets
        id: "parse_secrets"
        uses: toptal/actions/expose-json-outputs@main
        with:
          json: ${{ steps.secrets_manager.outputs.secrets }}

      - name: Trigger your-awesome-job-name job
        uses: toptal/jenkins-job-trigger-action@2.0.0
        with:
          jenkins_url: ${{ steps.parse_secrets.outputs.JENKINS_BUILD_URL }}
          jenkins_user: ${{ steps.parse_secrets.outputs.TOPTAL_TRIGGERBOT_USERNAME }}
          jenkins_token: ${{ steps.parse_secrets.outputs.TOPTAL_TRIGGERBOT_BUILD_TOKEN }}
          job_name: "the-name-of-your-jenkins-job"
          jenkins_client_id: ${{ steps.parse_secrets.outputs.JENKINS_CLIENT_ID }}
          jenkins_sa_credentials: ${{ steps.parse_secrets.outputs.JENKINS_SA_CREDENTIALS }}
          gcr_account_key: ${{ steps.parse_secrets.outputs.GCR_ACCOUNT_KEY }}
          job_params: |
            {
              "param_1": "value_1",
              "param_2": "value_2"
            }
          job_timeout: 3600 # Default 30 sec. (optional)
```
