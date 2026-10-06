#!/bin/sh
# Stands in for a host's node, yarn or corepack: it records that it ran, in the
# file $HOST_TOOL_MARKER names, and fails, so a launcher that ran it is caught.
# tests/launcher/host_tool.sh is the same file, for the other module.
echo "$0" >>"$HOST_TOOL_MARKER"
exit 97
