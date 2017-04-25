from __future__ import print_function

from io import open
import collections

import sys


class Spl(object):
    def __init__(self, filename):
        self._encoding = "ascii"
        self._delimiter = ";"
        self._f = {"system": {"ansi codepage": self._set_ansi_encoding,
                              "delimiter": self._set_delimiter},
                   "info states": self._add_info,
                   "record states": self._add_record,
                   "validation states": self._add_validation}

        self._records = {}
        self._validations = {}
        self._infos = collections.OrderedDict()

        self._parse(filename)

    def _parse(self, filename):
        try:
            section = None
            for line in open(filename, "rb").readlines():
                l = line.decode(self._encoding).strip().strip("\0")
                if len(l) < 2:
                    continue
                if l.startswith('['):
                    section = l[1:-1]
                else:
                    key, val = l.split("=", 1)
                    if key.isnumeric():
                        self._f.get(section.lower(), lambda y, z: 0)(int(key),val)
                    else:
                        if section.lower() in self._f:
                            s = self._f[section.lower()]
                            if key.lower() in s:
                                s[key.lower()](val)
        except Exception as e:
            print("Error when parsing {}: {}".format(filename, e), file=sys.stderr)

        if len(self._records) != len(self._validations):
            print("Filename: {} has {} records and {} validations".format(filename, len(self._records), len(self._validations)))

    def _set_ansi_encoding(self, e):
        self._encoding = "cp{}".format(e)

    def _set_delimiter(self, d):
        self._delimiter = d

    def _add_record(self, i, r):
        self._records[i] = r.split(self._delimiter)

    def _add_info(self, _, info):
        key, val = info.split(self._delimiter)[:2]
        self._infos[key] = val

    def _add_validation(self, i, v):
        self._validations[i] = v.split(self._delimiter)

    def records(self):
        for key, val in self._records.items():
            yield self._validations[key], val

    def key_records(self):
        for key, record in self._records.items():
            if key not in self._validations:
                continue
            yield key, self._validations[key], record