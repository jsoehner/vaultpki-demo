pid_file = "/tmp/pidfile"

vault {
  address = "http://vault:8200"
}

auto_auth {
  method "approle" {
    mount_path = "auth/approle"
    config = {
      role_id_file_path = "/vault/agent/roleid"
      secret_id_file_path = "/vault/agent/secretid"
      remove_secret_id_file_after_reading = false
    }
  }

  sink "file" {
    config = {
      path = "/vault/agent/token"
    }
  }
}

template {
  source      = "/vault/agent/cert.tpl"
  destination = "/certs/test.example.com.crt"
  command     = "kill -HUP 1"
}

template {
  source      = "/vault/agent/key.tpl"
  destination = "/certs/test.example.com.key"
  command     = "kill -HUP 1"
}
