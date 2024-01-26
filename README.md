# Terraform IAC monorepo for the Thirst Alert infrastructure

## Introduction

This repository aims to facilitate the seamless replication of Thirst Alert's infrastructure by simplifying the deployment process through a few terminal commands. While the project is still a work in progress, this document outlines the structure of the project and highlights workarounds employed to address common challenges in Infrastructure as Code (IAC) development.

## Structure

By setting up a base infrastructure, we can apply slightly different configurations using the `env` environment variable, which specifies the development or the production environment. This way, we can have different deployed environments which have slight differences, even though we wrote the infrastructure code only once, avoiding repetition.

The repo is mostly divided in modules. We decided to have some files at the root of the project that are then needed by all the other modules.

### Root

- `main.tf`: Invokes all other submodules, with all their dependencies.
- `locals.tf`: More like an utility file, contains some non-sensitive variables that are used by many modules.
- `provider.tf`: Initial plan was having all providers stored here, but Terraform doesn't work well with non `hashicorp` providers in sub-modules.
- `backend.tf`: Terraform stores its state file locally by default. We opted to host our state in a GCS bucket to allow both of us to have a synced state all the time.

### Modules

- `cloudbuild`: Manages our repos connection to the Google Cloudbuild service. Additionally, it sets up build triggers for our versions that containerize and store our applications in Google's Artifact Registry.
- `iam`: Google IAM permissions are all defined here. This allows us to keep an eye on how well we're applying [PoLP](https://en.wikipedia.org/wiki/Principle_of_least_privilege) to our Google identities and service accounts. It also allows to quickly add or remove privileges when in need.
- `secrets`: Handles sensitive information, including application secrets and resources within the repository. The process involves creating and managing secrets using Google Secret Manager, ensuring security without compromising workflow efficiency. We don't obviously want to store our secrets in plain text on Github, but we also don't want to provide all our secrets one by one when applying Terraform configuration. We also don't want to have a plain text environment file with all our secrets lying around on our machines. To avoid all this, we need to take a multi-step approach when adding a new secret to our project.
  1. We create a `google_secret_manager_secret` resource, and apply.
  2. On GCP, we find the newly creted resource in Secret Manager and manually insert the first version of our new secret.
  3. Back to terraform, we create a `google_secret_manager_secret_version` that references the previously created `google_secret_manager_secret`.
  4. We can then make the secret available to other modules by setting it as an output of the module, in its `outputs.tf` file.

  Hironically, while writing this document, I noticed I leaked a secret in my most recent commit, at the bottom of the `main.tf` file in the `secrets` module. The proof of my wondrous genius is still reviewable at commit `feddabc`. After quickly fixing it, I realized it is a great example of how scalable and fool-proof this secret management approach is. All I needed to do was disable the secret's version and create a new one with a new secret in it. Everything else just falls into place after applying the configuration.