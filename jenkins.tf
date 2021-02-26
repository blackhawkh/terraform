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
  tags = ["public-https"]
  network_interface {
    network = var.network
    access_config {}
  }

  metadata = {
    startup-script = file("scripts/jenkins.sh")
  }
}
