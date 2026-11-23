#!/bin/sh
if [ "$CONFIGURATION" = "Release" ]; then
    case " $SWIFT_ACTIVE_COMPILATION_CONDITIONS " in
        *" DEMO_MODE_ENABLED "*) echo "error: DEMO_MODE_ENABLED cannot be compiled into Release builds." >&2; exit 1 ;;
    esac
    case "$(printf '%s' "$DEMO_MODE_ENABLED" | tr '[:lower:]' '[:upper:]')" in
        YES|TRUE|1) echo "error: DEMO_MODE_ENABLED must be disabled for Release builds." >&2; exit 1 ;;
    esac
fi

