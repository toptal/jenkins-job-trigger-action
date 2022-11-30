# jenkins-job-trigger-action

Triggers Jenkins Jobs from GitHub actions

This action allows to trigger a job on Jenkins and get the build result.

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
      - name: Trigger your-awesome-job-name job
        uses: toptal/jenkins-job-trigger-action@master
        with:
          jenkins_url: "https://your.jenkins.url/"
          jenkins_user: ${{ secrets.JENKINS_USER }}
          jenkins_token: ${{ secrets.JENKINS_TOKEN }}
          proxy: ${{ secrets.JENKINS_PROXY }}
          job_name: "the-name-of-your-jenkins-job"
          job_params: |
            {
              "param_1": "value_1",
              "param_2": "value_2"
            }
          job_timeout: "3600" # Default 30 sec. (optional)
```


### Inputs

* `jenkins_url`: **required** Jenkins instance URL
* `jenkins_user`: **required** User name used for authentication
* `jenkins_token`: **required** Jenkins API token that belongs to jenkins_user
* `job_name`: **required** for jobs stored in a folder use `{folder-name}/job/{job-name}`
* `job_params`: Valid JSON with key-value params passed to the job
* `job_timeout`: Number of seconds to wait for the action to finish (Default 30)
* `proxy`: Proxy URL, includes username and password
* `async`: Set to true if you want to just trigger the job and dont wait for it to complete (Default false)

### Outputs

* `jenkins_job_url`: jenkins build URL if the scheduled job starts executing within given `job_timeout`
