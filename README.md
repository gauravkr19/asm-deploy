This is the repository for [Managing Infrastructure as Code with Terraform and Jenkins](https://cloud.google.com/solutions/managing-infrastructure-as-code-with-terraform-jenkins-and-gitops). It will demonstrate the use of Jenkins to continously integrate and deploy all Terraform code changes to the GCP environment. 

Jenkins Setup:

--> Jenkins is configured using JCasC plugin passed to Helm via the values.yaml

--> Jenkinsfile has the pipeline logic to provision infra in the target env.

