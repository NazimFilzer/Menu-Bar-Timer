#!/usr/bin/env bash
# PROTOTYPE launcher (throwaway): Week tab after the critique.
# Add ?variant=A|B|C|R&state=behind|ontrack|paused|past|empty&page=week|month&theme=light|dark
set -euo pipefail
open "$(dirname "$0")/../Prototype/week-critique-prototype.html"
