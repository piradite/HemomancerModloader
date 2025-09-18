extends RefCounted

class_name SandboxedHTTPClient

var _http_client: HTTPClient
var mod: Mod

signal request_completed(result, response_code, headers, body)

func _init():
	_http_client = HTTPClient.new()

func connect_to_host(host: String, port: int = 80, tls_options: TLSOptions = null) -> int:
	var permission = ModSettings.get_permission(mod.id, "http_client_connect")
	match permission:
		"always_allow":
			return _http_client.connect_to_host(host, port, tls_options)
		"always_deny":
			return FAILED
		"ask":
			var request_details = {
				"host": host,
				"port": port,
				"tls_options": tls_options,
				"requester": self
			}
			ModAPI._enqueue_permission_request({
				"mod": mod,
				"type": "http_client_connect",
				"details": request_details
			})
			return OK
	return FAILED

func request(method: int, url: String, headers: PackedStringArray = PackedStringArray(), body: String = "") -> int:
	var permission = ModSettings.get_permission(mod.id, "http_client_request")
	match permission:
		"always_allow":
			return _http_client.request(method, url, headers, body)
		"always_deny":
			return FAILED
		"ask":
			var request_details = {
				"method": method,
				"url": url,
				"headers": headers,
				"body": body,
				"requester": self
			}
			ModAPI._enqueue_permission_request({
				"mod": mod,
				"type": "http_client_request",
				"details": request_details
			})
			return OK
	return FAILED

func poll() -> int:
	return _http_client.poll()

func get_status() -> int:
	return _http_client.get_status()

func get_response_code() -> int:
	return _http_client.get_response_code()

func get_response_headers() -> PackedStringArray:
	return _http_client.get_response_headers()

func read_response_body_chunk() -> PackedByteArray:
	return _http_client.read_response_body_chunk()

func close() -> void:
	_http_client.close()
