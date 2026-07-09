#!/usr/bin/env python3
"""Utility to inspect silent-check evidence for a student.

Usage:
  python backend/scripts/check_silent.py --student-id <UUID> [--session-id <UUID>]

Reads DATABASE_URL from backend/.env and prints JSON results for quick analysis.
"""
import os
import json
import argparse
from dotenv import load_dotenv
from sqlalchemy import create_engine, text


def load_db_url():
    env_path = os.path.join(os.path.dirname(__file__), '..', '.env')
    if os.path.exists(env_path):
        load_dotenv(env_path)
    db_url = os.getenv('DATABASE_URL')
    if not db_url:
        raise RuntimeError('DATABASE_URL not found in .env')
    return db_url


def run_checks(database_url: str, student_id: str, session_id: str | None = None):
    engine = create_engine(database_url)
    out = {
        'student_id': student_id,
        'attendances': [],
        'fcm_token': None,
        'student_locations': {},
        'session': None,
    }

    with engine.connect() as conn:
        # 1) recent attendances for student
        att_q = text(
            """
            SELECT session_id, check_in_time, status, last_verified_at
            FROM attendances
            WHERE student_id = :student_id
            ORDER BY check_in_time DESC
            LIMIT 10
            """
        )
        rows = conn.execute(att_q, {'student_id': student_id}).fetchall()
        out['attendances'] = [dict(r) for r in rows]

        # If no session_id provided, pick the most recent attendance session_id
        if session_id is None and out['attendances']:
            session_id = out['attendances'][0].get('session_id')

        # 2) user fcm_token and last_login_at
        user_q = text(
            "SELECT user_id, fcm_token, last_login_at FROM users WHERE user_id = :student_id"
        )
        r = conn.execute(user_q, {'student_id': student_id}).first()
        if r:
            out['fcm_token'] = dict(r)

        # 3) session info
        if session_id:
            sess_q = text(
                "SELECT session_id, class_id, end_time, silent_check_scheduled_at FROM attendance_sessions WHERE session_id = :session_id"
            )
            s = conn.execute(sess_q, {'session_id': session_id}).first()
            if s:
                out['session'] = dict(s)

            # 4) student_locations for this student+session
            loc_q = text(
                """
                SELECT id, session_id, student_id, is_silent_check, timestamp, server_received_at,
                       verification_result, distance_m, radius_m
                FROM student_locations
                WHERE student_id = :student_id
                  AND session_id = :session_id
                ORDER BY server_received_at DESC NULLS LAST, timestamp DESC
                LIMIT 50
                """
            )
            locs = conn.execute(loc_q, {'student_id': student_id, 'session_id': session_id}).fetchall()
            out['student_locations'][str(session_id)] = [dict(r) for r in locs]

    return out


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--student-id', required=True)
    p.add_argument('--session-id', required=False)
    args = p.parse_args()

    try:
        db_url = load_db_url()
    except Exception as e:
        print(json.dumps({'error': str(e)}))
        raise

    res = run_checks(db_url, args.student_id, args.session_id)
    print(json.dumps(res, default=str, indent=2, ensure_ascii=False))


if __name__ == '__main__':
    main()
