#!/usr/bin/env python3
"""Print Google Play OAuth access token from service account JSON."""
from pathlib import Path

from google.auth.transport.requests import Request
from google.oauth2 import service_account

BASE_DIR = Path(__file__).resolve().parent.parent
KEY_FILE = BASE_DIR / "config" / "play-service-account.json"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]

credentials = service_account.Credentials.from_service_account_file(str(KEY_FILE), scopes=SCOPES)
credentials.refresh(Request())
print(credentials.token)
