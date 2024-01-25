output github_pat_secret_id {
	value = google_secret_manager_secret.github_pat_secret.secret_id
}

output mongodb_atlas_public_key {
  value = jsondecode(data.google_secret_manager_secret_version.mongodb_atlas_keys_secret_version.secret_data)["pub"]
}

output mongodb_atlas_private_key {
  value = jsondecode(data.google_secret_manager_secret_version.mongodb_atlas_keys_secret_version.secret_data)["priv"]
}

output mongodb_atlas_org_id {
	value = data.google_secret_manager_secret_version.mongodb_atlas_org_id_secret_version.secret_data
}

output mongodb_db_password {
	value = data.google_secret_manager_secret_version.mongodb_db_password_secret_version.secret_data
}