This is the repository for [Managing Infrastructure as Code with Terraform and Jenkins](https://cloud.google.com/solutions/managing-infrastructure-as-code-with-terraform-jenkins-and-gitops) solution. It will demonstrate the use of Jenkins to continously integrate and deploy all Terraform code changes to the GCP environment. 

Jenkins Setup:

--> Jenkins is configured uisng JCasC plugin passed to Helm via the values.yaml

--> Jenkinsfile has the pipeline logic to provision infra in the target env.

Listing out some of the issues with the existing code.

Issue-1: The Jenkins deployment makes use of deprecated Helm repo.

Approach to resolve: We may have to update the Helm repo. However, we are facing issue in passing the env var to container pods which worked fine with deprecated Helm repo. We are looking into it to fix it.
Also briefed Pavithra on this, and requested to her with Jenkins pipeline setup. She is looking into it. 

Issue-2: Google TF Module 'modules/project_services' is NOT able to enable the Services.

Approach to resolve: Haven't looked into, but can use the resource to enable the listed Services if the Module is not working.

Issue-2: Update the Terraform version (for Host machine and Jenkins Pods); Using 0.12.24 now

Approach to resolve: Latest version is 15.1; so will have to update to a stable Terraform version. This may also require some code update.

Issue-4: Provisioning the infra from windows machine has some issue.

Approach to resolve: This needs to be looked at too.


