extends Node

class_name SandboxedHTTPRequest

var _http_request: HTTPRequest
var mod: Mod

signal request_completed(result, response_code, headers, body)

func _ready():
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(func(result, response_code, headers, body):
		request_completed.emit(result, response_code, headers, body)
	)

func request(url: String, custom_headers: PackedStringArray = PackedStringArray(), ssl_validate_domain: bool = true, method: HTTPClient.Method = HTTPClient.METHOD_GET, request_data: String = "") -> int:
	var permission = ModSettings.get_permission(mod.id, "http_request")
	match permission:
		"always_allow":
			_http_request.set("ssl_validate_domain", ssl_validate_domain)
			return _http_request.request(url, custom_headers, method, request_data)
		"always_deny":
			return FAILED
		"ask":
			var request_details = {
				"url": url,
				"custom_headers": custom_headers,
				"ssl_validate_domain": ssl_validate_domain,
				"method": method,
				"request_data": request_data,
				"requester": self
			}
			ModAPI._enqueue_permission_request({
				"mod": mod,
				"type": "http_request",
				"details": request_details
			})
			return OK
	return FAILED

func get_body_len() -> int:
	return _http_request.get_body_len()

func get_downloaded_bytes() -> int:
	return _http_request.get_downloaded_bytes()

func get_http_client_status() -> int:
	return _http_request.get_http_client_status()

func cancel_request():
	_http_request.cancel_request()
