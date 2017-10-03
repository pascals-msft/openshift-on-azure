#!/usr/bin/env python
#
# json_value.py
#
# given a JSON object and a name, returns the value associated with the name
# (no error checking)

import sys, json

print(json.loads(sys.argv[1])[sys.argv[2]])

# print(sys.argv)
# print(len(sys.argv))
# for i in range(len(sys.argv)):
#     print i, sys.argv[i]

# parsed_json = json.loads(sys.argv[1])
# print(parsed_json[sys.argv[2]])
