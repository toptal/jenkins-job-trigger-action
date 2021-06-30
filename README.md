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
          job_name: "the-name-of-your-jenkins-job"
          job_params: '{"param_1":"value_1", "param_2":"value_2"}'
          job_timeout: "3600" # Default 30 sec. (optional)
          async: false # Default to false (optional)
```

It's also possible trigger a Jenkins job and don't wait for it to finish with the `async` option

```
name: Your GHA
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  your_job_name:
    name: Trigger Jenkins Job asynchronously
    runs-on: ubuntu-latest
    steps:
      - name: Trigger your-awesome-job-name job
        id: trigger-jenkins-job
        uses: toptal/jenkins-job-trigger-action@master
        with:
          jenkins_url: "https://your.jenkins.url/"
          jenkins_user: ${{ secrets.JENKINS_USER }}
          jenkins_token: ${{ secrets.JENKINS_TOKEN }}
          job_name: "the-name-of-your-jenkins-job"
          async: true
          
      - name: Debug
        run: echo "A job has been scheduled, see progress at ${{steps.trigger-jenkins-job.outputs.jenkins_job_url}}"
```
