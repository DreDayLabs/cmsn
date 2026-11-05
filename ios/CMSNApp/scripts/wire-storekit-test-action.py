#!/usr/bin/env python3
"""Copy the Run action's StoreKit configuration onto the screenshot Test action.

XcodeGen writes storeKitConfiguration only on LaunchAction. CMSNScreenshots
launches the app from TestAction, so that scheme needs the same file there.

Unit-test schemes are not patched. Those tests open the file with
SKTestSession, and a scheme Test action selection stops that session.
Idempotent.
"""

from pathlib import Path
import re
import sys
from typing import Optional

SCHEMES = Path(__file__).resolve().parents[1] / "CMSNApp.xcodeproj" / "xcshareddata" / "xcschemes"
# Only the UI-test scheme. Unit tests load the file through SKTestSession.
PATCH_TEST_ACTION = {"CMSNScreenshots.xcscheme"}
ELEMENT = re.compile(
    r"[ \t]*<StoreKitConfigurationFileReference\b.*?</StoreKitConfigurationFileReference>\n?",
    re.DOTALL,
)
ACTION = re.compile(r"(<(LaunchAction|TestAction)\b[^>]*>)(.*?)(</\2>)", re.DOTALL)


def element_in(body: str) -> Optional[str]:
    match = ELEMENT.search(body)
    return match.group(0) if match else None


def patch(text: str, scheme_name: str) -> str:
    actions = list(ACTION.finditer(text))
    launch = next((match for match in actions if match.group(2) == "LaunchAction"), None)
    test = next((match for match in actions if match.group(2) == "TestAction"), None)
    if launch is None or test is None:
        sys.exit(f"{scheme_name}: missing LaunchAction or TestAction")
    snippet = element_in(launch.group(3))
    if snippet is None:
        sys.exit(f"{scheme_name}: Run action has no StoreKit configuration")
    if element_in(test.group(3)):
        return text
    # Keep the newline that already follows the opening tag.
    body = test.group(3)
    if not body.startswith("\n"):
        body = "\n" + body
    indented = snippet if snippet.endswith("\n") else snippet + "\n"
    replacement = test.group(1) + "\n" + indented + body.lstrip("\n") + test.group(4)
    return text[: test.start()] + replacement + text[test.end() :]


def main() -> None:
    if not SCHEMES.is_dir():
        sys.exit(f"Missing schemes directory: {SCHEMES}")
    for scheme in sorted(SCHEMES.glob("*.xcscheme")):
        if scheme.name not in PATCH_TEST_ACTION:
            continue
        original = scheme.read_text()
        updated = patch(original, scheme.name)
        if updated != original:
            scheme.write_text(updated)
            print(f"Wired StoreKit configuration into {scheme.name} Test action")
        else:
            print(f"{scheme.name} Test action already references StoreKit")


if __name__ == "__main__":
    main()
