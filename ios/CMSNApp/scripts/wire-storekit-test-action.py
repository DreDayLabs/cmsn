#!/usr/bin/env python3
"""Point every shared scheme's Run and Test actions at Configuration.storekit.

The scheme file is three directories below ios/CMSNApp
(xcodeproj/xcshareddata/xcschemes). Xcode resolves the identifier from
that file. XcodeGen's default "../../" prefix does not reach
CMSNApp/Resources/Configuration.storekit. This rewrites the reference
and copies it onto the Test action, which is what Cmd+U and
`xcodebuild test` use. Idempotent.
"""

from pathlib import Path
import re
import sys
from typing import Optional

ROOT = Path(__file__).resolve().parents[1]
SCHEMES = ROOT / "CMSNApp.xcodeproj" / "xcshareddata" / "xcschemes"
STOREKIT = (ROOT / "CMSNApp" / "Resources" / "Configuration.storekit").resolve()
# Relative to each xcscheme file.
IDENTIFIER = "../../../CMSNApp/Resources/Configuration.storekit"
PATCH = {
    "CMSNApp.xcscheme",
    "CMSNAppTests.xcscheme",
    "CMSNScreenshots.xcscheme",
}
ELEMENT = re.compile(
    r"[ \t]*<StoreKitConfigurationFileReference\b.*?</StoreKitConfigurationFileReference>\n?",
    re.DOTALL,
)
ACTION = re.compile(r"(<(LaunchAction|TestAction)\b[^>]*>)(.*?)(</\2>)", re.DOTALL)
SNIPPET = (
    "      <StoreKitConfigurationFileReference\n"
    f'         identifier = "{IDENTIFIER}">\n'
    "      </StoreKitConfigurationFileReference>\n"
)


def element_in(body: str) -> Optional[str]:
    match = ELEMENT.search(body)
    return match.group(0) if match else None


def with_reference(text: str, action_name: str, scheme_name: str) -> str:
    actions = list(ACTION.finditer(text))
    match = next((item for item in actions if item.group(2) == action_name), None)
    if match is None:
        sys.exit(f"{scheme_name}: missing {action_name}")
    current = element_in(match.group(3))
    if current and IDENTIFIER in current and 'identifier = "%s"' % IDENTIFIER in current:
        return text
    body = ELEMENT.sub("", match.group(3))
    if not body.startswith("\n"):
        body = "\n" + body
    replacement = match.group(1) + "\n" + SNIPPET + body.lstrip("\n") + match.group(4)
    return text[: match.start()] + replacement + text[match.end() :]


def main() -> None:
    if not STOREKIT.is_file():
        sys.exit(f"Missing StoreKit configuration: {STOREKIT}")
    if not SCHEMES.is_dir():
        sys.exit(f"Missing schemes directory: {SCHEMES}")
    for scheme in sorted(SCHEMES.glob("*.xcscheme")):
        if scheme.name not in PATCH:
            continue
        original = scheme.read_text()
        updated = with_reference(original, "LaunchAction", scheme.name)
        updated = with_reference(updated, "TestAction", scheme.name)
        resolved = (scheme.parent / IDENTIFIER).resolve()
        if resolved != STOREKIT:
            sys.exit(
                f"{scheme.name}: {IDENTIFIER} resolves to {resolved}, expected {STOREKIT}"
            )
        if updated != original:
            scheme.write_text(updated)
            print(f"StoreKit configuration path set on {scheme.name}")
        else:
            print(f"{scheme.name} already points at {IDENTIFIER}")


if __name__ == "__main__":
    main()
