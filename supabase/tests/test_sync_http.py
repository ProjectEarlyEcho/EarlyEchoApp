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

from test_sync_integrity import (
    A, ADMIN, B, CHILD, OTHER_CHILD, OTHER_PARENT, PARENT,
    consent, dashboard_screening, screening,
)


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

    def sync_child_screening(self, value, projection=None, owner=A):
        return self.request("/rpc/sync_child_screening", {
            "p_screening": value,
            "p_dashboard": dashboard_screening(value) if projection is None else projection,
        }, owner)

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

    def test_parent_screenings_and_consent_are_private_and_immutable(self):
        for owner in (PARENT, OTHER_PARENT):
            with self.subTest(owner=owner):
                value = screening(owner=owner, anganwadi_id="HOME")
                log = consent(value)
                self.assertEqual(self.sync_screening(value, owner), (200, "inserted"))
                self.assertEqual(self.sync_screening(value, owner), (200, "replayed"))
                self.assertEqual(self.sync_consent(log, owner), (200, "inserted"))
                self.assertEqual(self.sync_consent(log, owner), (200, "replayed"))
                status, error = self.sync_screening({**value, "risk_level": "red"}, owner)
                self.assertEqual((status, error["code"]), (409, "PT409"))
                for other in (A, ADMIN, PARENT, OTHER_PARENT):
                    if other == owner:
                        continue
                    for table, record in (("screenings", value), ("consent_logs", log)):
                        self.assertEqual(self.request(f"/{table}?id=eq.{record['id']}&select=id", owner=other), (200, []))
                    self.assertEqual(self.sync_screening(value, other)[0], 403)
                    self.assertEqual(self.sync_consent(log, other)[0], 403)
                    self.assertEqual(self.sync_consent(consent(value, created_by=other), other)[0], 403)
                for invalid in (
                    consent(value, anganwadi_id="OTHER-HOME"),
                    consent(value, session_id=str(uuid.uuid4())),
                    consent(value, session_id=None),
                ):
                    self.assertEqual(self.sync_consent(invalid, owner)[0], 403)
                    self.assertEqual(self.request("/consent_logs", invalid, owner)[0], 403)
                for table, record in (("screenings", value), ("consent_logs", log)):
                    for method, payload in (("PATCH", {"created_by": A}), ("DELETE", None)):
                        status, error = self.request(f"/{table}?id=eq.{record['id']}", payload, owner, method)
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

    def test_linked_replay_normalizes_both_payloads_and_keeps_consent_link(self):
        value = screening(vttl_ms=1840)
        projection = dashboard_screening(value)
        self.assertEqual(self.sync_child_screening(value, projection), (200, "inserted"))
        retry = {**value, "vttl_ms": 1840.0, "session_date": "2026-09-18T15:30:00+05:30"}
        self.assertEqual(self.sync_child_screening(retry, projection), (200, "replayed"))
        self.assertEqual(self.sync_child_screening(retry), (200, "replayed"))
        log = consent(value)
        self.assertEqual(self.sync_consent(log), (200, "inserted"))
        self.assertEqual(self.sync_consent(log), (200, "replayed"))
        for table in ("screenings", "screening_sessions"):
            self.assertEqual(self.request(f"/{table}?id=eq.{value['id']}&select=id"), (200, [{"id": value["id"]}]))

    def test_care_visibility_does_not_expose_mobile_ownership(self):
        value = screening()
        projection = dashboard_screening(value)
        self.assertEqual(self.sync_child_screening(value, projection), (200, "inserted"))
        log = consent(value)
        self.assertEqual(self.sync_consent(log), (200, "inserted"))
        for owner in (A, B, PARENT):
            self.assertEqual(self.request(f"/screening_sessions?id=eq.{value['id']}&select=id,child_id,created_by", owner=owner),
                             (200, [{"id": value["id"], "child_id": CHILD, "created_by": A}]))
        for owner in (ADMIN, OTHER_PARENT):
            self.assertEqual(self.request(f"/screening_sessions?id=eq.{value['id']}&select=id", owner=owner), (200, []))
        for owner in (B, PARENT, ADMIN, OTHER_PARENT):
            self.assertEqual(self.request(f"/screenings?id=eq.{value['id']}&select=id", owner=owner), (200, []))
            self.assertEqual(self.request(f"/consent_logs?id=eq.{log['id']}&select=id", owner=owner), (200, []))
            status, error = self.sync_child_screening(value, projection, owner)
            self.assertEqual((status, error["code"]), (403, "42501"))
        for owner in (A, B, PARENT):
            for method, payload in (("PATCH", {"risk_level": "red"}), ("DELETE", None)):
                status, error = self.request(f"/screening_sessions?id=eq.{value['id']}", payload, owner, method)
                self.assertEqual((status, error["code"]), (403, "42501"))

    def test_denied_linked_insert_rolls_back_mobile_and_cannot_accept_consent(self):
        for owner, child in ((A, OTHER_CHILD), (PARENT, CHILD), (ADMIN, CHILD)):
            with self.subTest(owner=owner):
                value = screening(owner=owner)
                status, error = self.sync_child_screening(value, dashboard_screening(value, child_id=child), owner)
                self.assertEqual((status, error["code"]), (403, "42501"))
                self.assertEqual(self.request(f"/screenings?id=eq.{value['id']}&select=id", owner=owner), (200, []))
                # B is assigned to both children, so RLS cannot hide a partial projection.
                self.assertEqual(self.request(f"/screening_sessions?id=eq.{value['id']}&select=id", owner=B), (200, []))
                self.assertEqual(self.sync_consent(consent(value), owner)[0], 403)
        self.assertEqual(self.sync_child_screening(screening(), owner=None)[0], 401)

    def test_projection_mismatch_returns_conflict_without_writing_mobile(self):
        for change in (
            {"id": str(uuid.uuid4())}, {"risk_level": "red"}, {"vttl_ms": 2000},
            {"pfv_std": 8}, {"cvr_ratio": 0.9}, {"child_age_months": 31},
            {"audio_source": "different"}, {"created_at": "2026-09-19T10:00:00Z"},
            {"analysis_status": "INCOMPLETE"}, {"quality_reasons": ["no_audio"]},
        ):
            with self.subTest(change=change):
                value = screening()
                status, error = self.sync_child_screening(value, dashboard_screening(value, **change))
                self.assertEqual((status, error["code"]), (409, "PT409"))
                self.assertEqual(self.request(f"/screenings?id=eq.{value['id']}&select=id"), (200, []))

    def test_visible_dashboard_conflict_rolls_back_mobile_for_either_owner(self):
        for owner in (A, B):
            with self.subTest(existing_owner=owner):
                value = screening()
                projection = dashboard_screening(value)
                existing = {**projection, "created_by": owner}
                if owner == A:
                    existing["decision_trace"] = {"rule": "earlier_capture"}
                self.assertEqual(self.request("/screening_sessions", existing, owner)[0], 201)
                status, error = self.sync_child_screening(value, projection)
                self.assertEqual((status, error["code"]), (409, "PT409"))
                self.assertEqual(self.request(f"/screenings?id=eq.{value['id']}&select=id"), (200, []))
                self.assertEqual(self.request(f"/screening_sessions?id=eq.{value['id']}&select=created_by,decision_trace"),
                                 (200, [{"created_by": owner, "decision_trace": existing["decision_trace"]}]))

    def test_existing_mobile_or_dashboard_record_acquires_matching_counterpart_once(self):
        for existing_table in ("screenings", "screening_sessions"):
            with self.subTest(existing_table=existing_table):
                value = screening(owner=B)
                projection = dashboard_screening(value)
                if existing_table == "screenings":
                    self.assertEqual(self.sync_screening(value, B), (200, "inserted"))
                else:
                    self.assertEqual(self.request("/screening_sessions", projection, B)[0], 201)
                self.assertEqual(self.sync_child_screening(value, projection, B), (200, "inserted"))
                self.assertEqual(self.sync_child_screening(value, projection, B), (200, "replayed"))
                status, error = self.sync_child_screening(value, {**projection, "child_id": OTHER_CHILD}, B)
                self.assertEqual((status, error["code"]), (409, "PT409"))
                self.assertEqual(self.request(f"/screening_sessions?id=eq.{value['id']}&select=child_id", owner=B),
                                 (200, [{"child_id": CHILD}]))

    def test_concurrent_linked_http_replays_create_exactly_one_pair(self):
        value = screening()
        barrier = threading.Barrier(6)

        def attempt(_):
            barrier.wait(timeout=10)
            return self.sync_child_screening(value)

        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
            outcomes = list(pool.map(attempt, range(6)))
        self.assertEqual(outcomes.count((200, "inserted")), 1)
        self.assertEqual(outcomes.count((200, "replayed")), 5)
        for table in ("screenings", "screening_sessions"):
            self.assertEqual(self.request(f"/{table}?id=eq.{value['id']}&select=id"), (200, [{"id": value["id"]}]))

    def test_concurrent_linked_conflicts_preserve_consistent_mobile_and_dashboard(self):
        for field in ("risk_level", "decision_trace"):
            with self.subTest(field=field):
                value = screening()
                barrier = threading.Barrier(2)

                def attempt(candidate):
                    barrier.wait(timeout=10)
                    mobile = {**value, "risk_level": candidate} if field == "risk_level" else value
                    projection = dashboard_screening(mobile)
                    if field == "decision_trace":
                        projection["decision_trace"] = {"rule": candidate}
                    return self.sync_child_screening(mobile, projection)

                candidates = ("green", "red")
                with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
                    outcomes = list(pool.map(attempt, candidates))
                self.assertEqual(outcomes.count((200, "inserted")), 1)
                failure = next((status, error) for status, error in outcomes if status != 200)
                self.assertEqual((failure[0], failure[1]["code"]), (409, "PT409"))
                winner = candidates[outcomes.index((200, "inserted"))]
                for table in ("screenings", "screening_sessions"):
                    status, rows = self.request(f"/{table}?id=eq.{value['id']}&select=id,risk_level")
                    self.assertEqual(status, 200)
                    self.assertEqual(rows, [{"id": value["id"], "risk_level": winner if field == "risk_level" else "yellow"}])
                if field == "decision_trace":
                    self.assertEqual(self.request(f"/screening_sessions?id=eq.{value['id']}&select=decision_trace"),
                                     (200, [{"decision_trace": {"rule": winner}}]))


if __name__ == "__main__":
    unittest.main(verbosity=2)
