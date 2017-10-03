#!/usr/bin/env python
#
# Given a JSON object and a name, returns the value associated with the name
# (no error checking)
# Example:
#   $ ./json_value.py '{"a":"value_a","b":"value_b"}' "b"
#   value_b
#   $
import sys, json
print(json.loads(sys.argv[1])[sys.argv[2]])
