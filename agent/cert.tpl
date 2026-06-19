{{- with secret "pki_int/issue/web-server" "common_name=test.example.com" "ttl=1m" -}}
{{ .Data.certificate }}
{{ range .Data.ca_chain }}
{{ . }}
{{ end }}
{{- end -}}
