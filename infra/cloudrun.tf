resource "google_artifact_registry_repository" "docker-repo" {
  location      = "us-central1"
  repository_id = "docker"
  description   = "example docker repository"
  format        = "DOCKER"

  depends_on = [ google_project_service.artifactregistry ]
}