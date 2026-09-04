#!/usr/bin/env python3
"""Local protocol fixture. No credentials, inference, or network access."""
import json
import sys


def emit(value):
    print(json.dumps(value), flush=True)


for line in sys.stdin:
    request = json.loads(line)
    method = request.get("method")
    request_id = request.get("id")
    if request_id is None:
        continue
    if method == "initialize":
        emit({"id": request_id, "result": {"userAgent": "fixture"}})
    elif method == "account/read":
        emit({"id": request_id, "result": {"account": None, "requiresOpenaiAuth": True}})
    elif method == "test/timeout":
        continue
    elif method == "test/exit":
        sys.exit(7)
    elif method == "test/error":
        emit({"id": request_id, "error": {"code": -1, "message": "Fixture failure"}})
    elif method == "test/events":
        emit({"id": request_id, "result": {}})
        emit({"method": "item/completed", "params": {"threadId": "fixture-thread", "item": {"type": "imageGeneration", "status": "completed", "result": "aW1hZ2U="}}})
        emit({"method": "turn/completed", "params": {"threadId": "fixture-thread", "turn": {"status": "completed"}}})
    else:
        emit({"id": request_id, "result": {}})
