output github_pat_secret_id {
	value = google_secret_manager_secret.github_pat_secret.secret_id
}

output mongodb_db_password {
	value = data.google_secret_manager_secret_version.mongodb_db_password_secret_version.secret_data
}

output be_secrets {
  value = data.google_secret_manager_secret_version.be_secrets_secret_version.secret_data
}

output gitops_argocd_image_updater_key {
  value = data.google_secret_manager_secret_version.gitops_argocd_image_updater_key_secret_version.secret_data
}