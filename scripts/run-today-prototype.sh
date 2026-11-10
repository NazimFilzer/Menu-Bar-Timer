#!/usr/bin/env bash
# PROTOTYPE launcher (throwaway): Today tab on the shared dashboard grammar.
# Add ?variant=G|A|B|C|R&state=active|paused|idle|reached|empty|past&tag=header|row|popover|card&theme=light|dark
set -euo pipefail
open "$(dirname "$0")/../Prototype/today-grammar-prototype.html"
