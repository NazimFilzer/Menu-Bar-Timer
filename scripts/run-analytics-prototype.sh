#!/usr/bin/env bash
# PROTOTYPE launcher (throwaway): Analytics on the shared grammar. ?variant=A|B|C|R&range=week|month|year|all&offset=0|-1&theme=light|dark
set -euo pipefail
open "$(dirname "$0")/../Prototype/analytics-grammar-prototype.html"
