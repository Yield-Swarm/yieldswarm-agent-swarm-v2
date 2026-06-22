"""GitHub REST API client — public metadata only, rate-limit aware."""

from __future__ import annotations

import json
import os
import time
from typing import Any, Dict, List, Optional
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen


class GitHubClient:
    def __init__(self, token: Optional[str] = None, user_agent: str = "yieldswarm-scraper-engine/1.0"):
        self.token = token or os.getenv("GITHUB_TOKEN") or os.getenv("GH_TOKEN")
        self.user_agent = user_agent
        self._last_request = 0.0
        self.min_interval = 0.35 if self.token else 1.2

    def _headers(self) -> Dict[str, str]:
        h = {
            "Accept": "application/vnd.github+json",
            "User-Agent": self.user_agent,
            "X-GitHub-Api-Version": "2022-11-28",
        }
        if self.token:
            h["Authorization"] = f"Bearer {self.token}"
        return h

    def _get(self, url: str) -> Any:
        elapsed = time.monotonic() - self._last_request
        if elapsed < self.min_interval:
            time.sleep(self.min_interval - elapsed)
        req = Request(url, headers=self._headers())
        try:
            with urlopen(req, timeout=30) as resp:
                self._last_request = time.monotonic()
                return json.loads(resp.read().decode("utf-8"))
        except HTTPError as e:
            if e.code == 401 and self.token:
                # Stale/invalid token in env — retry once without auth for public repos
                self.token = None
                self.min_interval = 1.2
                req = Request(url, headers=self._headers())
                with urlopen(req, timeout=30) as resp:
                    self._last_request = time.monotonic()
                    return json.loads(resp.read().decode("utf-8"))
            body = e.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"GitHub API {e.code} for {url}: {body[:300]}") from e
        except URLError as e:
            raise RuntimeError(f"GitHub request failed for {url}: {e}") from e

    def repo_metadata(self, owner: str, repo: str) -> Dict[str, Any]:
        data = self._get(f"https://api.github.com/repos/{owner}/{repo}")
        return {
            "full_name": data.get("full_name"),
            "description": data.get("description"),
            "default_branch": data.get("default_branch"),
            "stars": data.get("stargazers_count"),
            "forks": data.get("forks_count"),
            "open_issues": data.get("open_issues_count"),
            "language": data.get("language"),
            "updated_at": data.get("updated_at"),
            "html_url": data.get("html_url"),
            "license": (data.get("license") or {}).get("spdx_id"),
        }

    def list_issues(
        self,
        owner: str,
        repo: str,
        keywords: List[str],
        per_page: int = 30,
    ) -> List[Dict[str, Any]]:
        q = quote(f"repo:{owner}/{repo} is:issue")
        url = f"https://api.github.com/search/issues?q={q}&per_page={per_page}&sort=updated"
        data = self._get(url)
        hits = []
        for item in data.get("items", []):
            blob = f"{item.get('title', '')} {item.get('body') or ''}".lower()
            matched = [k for k in keywords if k.lower() in blob]
            if not keywords or matched:
                hits.append(
                    {
                        "number": item.get("number"),
                        "title": item.get("title"),
                        "state": item.get("state"),
                        "html_url": item.get("html_url"),
                        "updated_at": item.get("updated_at"),
                        "matched_keywords": matched,
                    }
                )
        return hits

    def list_pulls(self, owner: str, repo: str, keywords: List[str], per_page: int = 20) -> List[Dict[str, Any]]:
        url = f"https://api.github.com/repos/{owner}/{repo}/pulls?state=all&per_page={per_page}"
        data = self._get(url)
        hits = []
        for item in data:
            blob = f"{item.get('title', '')} {item.get('body') or ''}".lower()
            matched = [k for k in keywords if k.lower() in blob]
            if not keywords or matched:
                hits.append(
                    {
                        "number": item.get("number"),
                        "title": item.get("title"),
                        "state": item.get("state"),
                        "html_url": item.get("html_url"),
                        "updated_at": item.get("updated_at"),
                        "matched_keywords": matched,
                    }
                )
        return hits

    def search_code_snippets(
        self,
        owner: str,
        repo: str,
        keywords: List[str],
        per_page: int = 10,
    ) -> List[Dict[str, Any]]:
        if not self.token:
            return []
        results: List[Dict[str, Any]] = []
        for kw in keywords[:5]:
            q = quote(f"repo:{owner}/{repo} {kw}")
            url = f"https://api.github.com/search/code?q={q}&per_page={per_page}"
            try:
                data = self._get(url)
            except RuntimeError:
                continue
            for item in data.get("items", []):
                results.append(
                    {
                        "name": item.get("name"),
                        "path": item.get("path"),
                        "html_url": item.get("html_url"),
                        "keyword": kw,
                    }
                )
        return results
