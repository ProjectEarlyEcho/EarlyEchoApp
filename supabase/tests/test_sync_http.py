"""Acceptance tests against native PostgREST and the disposable SQL fixture.

Prepare a separate database with test_sync_integrity.py --setup-only, expose it
through PostgREST, and set SYNC_HTTP_URL and SYNC_HTTP_JWT_SECRET. This runner
uses synthetic fixture identities and never provisions users or resets schemas.
"""

import base64
import concurrent.futures
import hashlib
import hmac
import json
import os
import threading
import time
import unittest
import urllib.error
import urllib.request
import uuid

from test_sync_integrity import A, ADMIN, B, PARENT, consent, screening


def encode(value):
    data = json.dumps(value, separators=(",", ":")).encode()
    return base64.urlsafe_b64encode(data).decode().rstrip("=")


class SyncHttpTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base_url = os.environ["SYNC_HTTP_URL"].rstrip("/")
        cls.secret = os.environ["SYNC_HTTP_JWT_SECRET"].encode()

    def token(self, owner):
        message = encode({"alg": "HS256", "typ": "JWT"}) + "." + encode({
            "role": "authenticated", "sub": owner, "exp": int(time.time()) + 300,
        })
        signature = hmac.new(self.secret, message.encode(), hashlib.sha256).digest()
        return message + "." + base64.urlsafe_b64encode(signature).decode().rstrip("=")

    def request(self, path, payload=None, owner=A, method=None):
        headers = {"Content-Type": "application/json"}
        if owner is not None:
            headers["Authorization"] = "Bearer " + self.token(owner)
        request = urllib.request.Request(
            self.base_url + path,
            data=None if payload is None else json.dumps(payload).encode(),
            headers=headers,
            method=method,
        )
        try:
            response = urllib.request.urlopen(request, timeout=15)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            body = response.read()
            return response.status, json.loads(body) if body else None

    def sync_screening(self, value, owner=A):
        return self.request("/rpc/sync_screening", {"p_screening": value}, owner)

    def sync_consent(self, value, owner=A):
        return self.request("/rpc/sync_consent_log", {"p_consent": value}, owner)

    def test_lost_response_replay_normalizes_json_and_timestamps(self):
        value = screening(vttl_ms=1840)
        self.assertEqual(self.sync_screening(value), (200, "inserted"))
        retry = {
            **value, "vttl_ms": 1840.0,
            "session_date": "2026-09-18T15:30:00+05:30",
            "created_at": "2000-01-01T00:00:00Z",
        }
        self.assertEqual(self.sync_screening(retry), (200, "replayed"))
        self.assertEqual(
            self.request(f"/screenings?id=eq.{value['id']}&select=id"),
            (200, [{"id": value["id"]}]),
        )

    def test_conflict_status_preserves_committed_record(self):
        value = screening()
        self.assertEqual(self.sync_screening(value), (200, "inserted"))
        status, error = self.sync_screening({**value, "risk_level": "red"})
        self.assertEqual(status, 409)
        self.assertEqual(error["code"], "PT409")
        self.assertEqual(
            self.request(f"/screenings?id=eq.{value['id']}&select=risk_level"),
            (200, [{"risk_level": "yellow"}]),
        )

    def test_authenticated_ownership_and_anonymous_denial(self):
        value = screening()
        self.assertEqual(self.sync_screening(value), (200, "inserted"))
        log = consent(value)
        self.assertEqual(self.sync_consent(log), (200, "inserted"))
        for owner in (B, ADMIN, PARENT):
            with self.subTest(owner=owner):
                for table, record in (("screenings", value), ("consent_logs", log)):
                    self.assertEqual(
                        self.request(f"/{table}?id=eq.{record['id']}&select=id", owner=owner),
                        (200, []),
                    )
                status, error = self.sync_screening(value, owner)
                self.assertEqual(status, 403)
                self.assertEqual(error["code"], "42501")
        self.assertEqual(self.sync_screening(screening(), owner=None)[0], 401)
        status, error = self.sync_screening(screening(owner=PARENT), PARENT)
        self.assertEqual((status, error["code"]), (403, "42501"))

    def test_consent_replay_conflict_and_cross_owner_link(self):
        value = screening()
        self.assertEqual(self.sync_screening(value), (200, "inserted"))
        log = consent(value)
        self.assertEqual(self.sync_consent(log), (200, "inserted"))
        self.assertEqual(self.sync_consent(log), (200, "replayed"))
        status, error = self.sync_consent({**log, "worker_name": "Different worker"})
        self.assertEqual((status, error["code"]), (409, "PT409"))
        invalid = consent(value, created_by=B)
        self.assertEqual(self.sync_consent(invalid, B)[0], 403)
        self.assertEqual(self.sync_consent(consent(value, session_id=str(uuid.uuid4())))[0], 403)

    def test_direct_mutation_and_profile_escalation_denied(self):
        value = screening()
        self.assertEqual(self.sync_screening(value), (200, "inserted"))
        for method, payload in (("PATCH", {"risk_level": "red"}), ("DELETE", None)):
            status, error = self.request(
                f"/screenings?id=eq.{value['id']}", payload, method=method,
            )
            self.assertEqual((status, error["code"]), (403, "42501"))
        for change in ({"role": "admin"}, {"anganwadi_id": "AW-OTHER"}):
            status, error = self.request(f"/profiles?id=eq.{A}", change, method="PATCH")
            self.assertEqual((status, error["code"]), (403, "42501"))

    def test_concurrent_http_replays_create_one_record(self):
        value = screening()
        barrier = threading.Barrier(6)

        def attempt(_):
            barrier.wait(timeout=10)
            return self.sync_screening(value)

        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
            outcomes = list(pool.map(attempt, range(6)))
        self.assertEqual(outcomes.count((200, "inserted")), 1)
        self.assertEqual(outcomes.count((200, "replayed")), 5)

    def test_concurrent_http_conflict_keeps_one_winner(self):
        value = screening()
        barrier = threading.Barrier(2)

        def attempt(risk):
            barrier.wait(timeout=10)
            return self.sync_screening({**value, "risk_level": risk})

        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            outcomes = list(pool.map(attempt, ("green", "red")))
        self.assertEqual(sum(result == (200, "inserted") for result in outcomes), 1)
        self.assertEqual(sum(status == 409 for status, _ in outcomes), 1)
        status, rows = self.request(f"/screenings?id=eq.{value['id']}&select=id,risk_level")
        self.assertEqual(status, 200)
        self.assertEqual(len(rows), 1)
        self.assertIn(rows[0]["risk_level"], ("green", "red"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
