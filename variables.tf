variable "name" {
  default = "rabbitmq"
}

variable "image" {
  default = "rabbitmq"
}

variable "namespace" {
  default = "rabbitmq"
}

variable "epmd_port" {
  default = 4369
}

variable "amqp_port" {
  default = 5672
}

variable "stats_port" {
  default = 15672
}

variable "dist_port" {
  default = 25672
}

variable "service_type" {
  default = "ClusterIP"
}

variable "replicas" {
  default = 3
}

variable "resources" {
  default = {
    requests = {
      cpu    = 0
      memory = 0
    }

    limits = {
      cpu    = 1
      memory = "1Gi"
    }
  }
}