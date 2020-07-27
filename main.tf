resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_service" "this" {
  metadata {
    name      = var.name
    namespace = kubernetes_namespace.this.metadata[0].name

    labels = {
      app = var.name
    }
  }

  spec {
    port {
      name        = "epmd"
      protocol    = "TCP"
      port        = var.epmd_port
      target_port = var.epmd_port
    }

    port {
      name        = "amqp"
      protocol    = "TCP"
      port        = var.amqp_port
      target_port = var.amqp_port
    }

    port {
      name        = "dist"
      protocol    = "TCP"
      port        = var.dist_port
      target_port = var.dist_port
    }

    port {
      name        = "stats"
      protocol    = "TCP"
      port        = var.stats_port
      target_port = var.stats_port
    }

    selector = {
      app = var.name
    }

    type = var.service_type
  }
}

resource "kubernetes_service" "this-headless" {
  metadata {
    name      = "rabbitmq-headless"
    namespace = kubernetes_namespace.this.metadata[0].name

    labels = {
      app = var.name
    }
  }

  spec {
    port {
      name        = "epmd"
      protocol    = "TCP"
      port        = var.epmd_port
      target_port = var.epmd_port
    }

    port {
      name        = "amqp"
      protocol    = "TCP"
      port        = var.amqp_port
      target_port = var.amqp_port
    }

    port {
      name        = "dist"
      protocol    = "TCP"
      port        = var.dist_port
      target_port = var.dist_port
    }

    port {
      name        = "stats"
      protocol    = "TCP"
      port        = var.stats_port
      target_port = var.stats_port
    }

    selector = {
      app = var.name
    }

    cluster_ip = "None"
    type       = var.service_type
  }
}

resource "kubernetes_config_map" "this" {
  metadata {
    name      = var.name
    namespace = kubernetes_namespace.this.metadata[0].name

    labels = {
      app = var.name
    }
  }

  data = {
    enabled_plugins = "[rabbitmq_management]."

    "rabbitmq.conf" = "cluster_formation.peer_discovery_backend = dns\ncluster_formation.dns.hostname = rabbitmq-0.rabbitmq.rabbitmq.svc.cluster.local\nloopback_users.guest = false\nlisteners.tcp.default = 5672\n"
  }
}

resource "kubernetes_secret" "this-cookie" {
  metadata {
    name      = var.name
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  data = {
    cookie = "dksjfls"
  }

  type = "Opaque"
}

resource "kubernetes_secret" "this" {
  metadata {
    name      = "rabbitmq-credentials"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  data = {
    pass = "guest"
    user = "guest"
  }

  type = "Opaque"
}

resource "kubernetes_stateful_set" "this" {
  metadata {
    name      = var.name
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = var.name
      }
    }

    template {
      metadata {
        labels = {
          app = var.name
        }
      }

      spec {
        volume {
          name = "conf"

          config_map {
            name = "rabbitmq"

            items {
              key  = "rabbitmq.conf"
              path = "rabbitmq.conf"
            }

            items {
              key  = "enabled_plugins"
              path = "enabled_plugins"
            }
          }
        }

        container {
          name  = var.name
          image = var.image

          resources {
            requests {
              cpu    = var.resources.requests.cpu
              memory = var.resources.requests.memory
            }

            limits {
              cpu    = var.resources.limits.cpu
              memory = var.resources.limits.memory
            }
          }

          port {
            name           = "epmd"
            container_port = var.epmd_port
            protocol       = "TCP"
          }

          port {
            name           = "amqp"
            container_port = var.amqp_port
            protocol       = "TCP"
          }

          port {
            name           = "dist"
            container_port = var.dist_port
            protocol       = "TCP"
          }

          port {
            name           = "stats"
            container_port = var.stats_port
            protocol       = "TCP"
          }

          env {
            name = "RABBITMQ_ERLANG_COOKIE"

            value_from {
              secret_key_ref {
                name = kubernetes_secret.this-cookie.metadata[0].name
                key  = "cookie"
              }
            }
          }

          env {
            name = "RABBITMQ_DEFAULT_USER"

            value_from {
              secret_key_ref {
                name = kubernetes_secret.this.metadata[0].name
                key  = "user"
              }
            }
          }

          env {
            name = "RABBITMQ_DEFAULT_PASS"

            value_from {
              secret_key_ref {
                name = kubernetes_secret.this.metadata[0].name
                key  = "pass"
              }
            }
          }

          env {
            name  = "RABBITMQ_USE_LONGNAME"
            value = "true"
          }

          volume_mount {
            name       = "conf"
            mount_path = "/etc/rabbitmq"
          }
        }

        subdomain = kubernetes_service.this-headless.metadata[0].name
      }
    }

    update_strategy {
      type = "RollingUpdate"

      rolling_update {
        partition = 0
      }
    }

    volume_claim_template {
      metadata {
        name = "data"
      }

      spec {
        access_modes = ["ReadWriteOnce"]

        resources {
          requests = {
            storage = "1Gi"
          }
        }
      }
    }

    service_name = kubernetes_service.this.metadata[0].name
  }
}