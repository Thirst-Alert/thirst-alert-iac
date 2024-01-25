output github_pat_secret_id {
	value = google_secret_manager_secret.github_pat_secret.secret_id
}