{{- with secret "pki_int/issue/web-server" "common_name=test.example.com" "ttl=1m" -}}
{{ .Data.private_key }}
{{- end -}}
