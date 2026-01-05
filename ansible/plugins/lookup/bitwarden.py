from __future__ import annotations

import json
import os
import subprocess

from ansible.errors import AnsibleLookupError
from ansible.plugins.lookup import LookupBase


class LookupModule(LookupBase):
    def run(self, terms, variables=None, **kwargs):
        session = os.environ.get("BW_SESSION", "")
        if not session:
            raise AnsibleLookupError("BW_SESSION environment variable is not set")

        results = []
        for term in terms:
            results.append(self._get_password(term, session))
        return results

    def _get_password(self, term, session):
        cmd = ["bw", "list", "items", "--search", term, "--session", session]
        try:
            output = subprocess.check_output(cmd, text=True)
        except subprocess.CalledProcessError as exc:
            raise AnsibleLookupError(f"Bitwarden lookup failed for '{term}': {exc}") from exc

        try:
            items = json.loads(output)
        except json.JSONDecodeError as exc:
            raise AnsibleLookupError("Failed to parse Bitwarden response") from exc

        if not isinstance(items, list) or not items:
            raise AnsibleLookupError(f"No Bitwarden items found matching '{term}'")

        item = next((i for i in items if i.get("name") == term), items[0])
        password = (item.get("login") or {}).get("password")
        if not password:
            raise AnsibleLookupError(f"No password found for Bitwarden item '{term}'")

        return password
