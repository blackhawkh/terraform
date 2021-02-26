// Can be create static public IP and configure DNS in any name server (Google DNS, CloudFlare etc)
// For normal production need to move docker registry to separate server(-s) or SaaS solution
// need to create additional disk for $JENKINS_HOME (it can be resized on the fly and have possibility to backup)
// via metadata can be provided initial jenkins password, or just connect Jenkins to LDAP/SSO

resource "google_compute_instance" "jenkins" {
  machine_type = "n1-standard-2"
  name         = "jenkins"
  zone         = var.zone
  boot_disk {
    initialize_params {
      image = "centos-7-v20210217"
      size  = 20
      type  = "pd-standard"
    }
  }
  tags = ["public-https", "public-http", "my-instance"]
  network_interface {
    network = var.network
    access_config {}
  }

  metadata = {
    startup-script = file("scripts/jenkins.sh")
  }
}

resource "google_compute_firewall" "allow-http" {
  name          = "allow-http"
  network       = var.network
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["public-http"]
  allow {
    protocol = "tcp"
    ports    = ["80", "8080"]
  }
}

resource "google_compute_firewall" "allow-https" {
  name          = "allow-https"
  network       = var.network
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["public-https"]
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
}

resource "google_compute_firewall" "my-instance" {
  name          = "my-instance"
  network       = var.network
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["my-instance"]
  allow {
    protocol = "tcp"
    ports    = ["9000"]
  }
}