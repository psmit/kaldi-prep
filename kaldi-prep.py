#!/usr/bin/env python
from __future__ import print_function

import argparse
import tempfile
import os
import sys


from os.path import join, realpath, abspath, dirname
from os import chdir
from shutil import rmtree
from subprocess import check_call

from lib.cache import make_cache
from lib.corpus import Corpus

from corpora import *
import corpora

corpus_map = {}
for cls in Corpus.__subclasses__():
    c = cls()
    corpus_map[c.name.lower()] = c
    corpus_map["{}-{}".format(c.lang, c.code).lower()] = c


def get_status(args):
    print("Status")
    for cls in Corpus.__subclasses__():
        print("{}".format(cls()))


def create_cache(args):
    print("Cache")
    c = corpus_map[args.corpus.lower()]
    tmp = tempfile.mkdtemp()
    c.make_base_dir({'TEAMWORK': '/m/teamwork/t40511_asr'}, tmp)

    make_cache(tmp, abspath(c.new_cache_dir()))

    rmtree(tmp)


def dataset(args):
    print("Dataset")
    c = corpus_map[args.corpus.lower()]
    c.get_dataset(args.dataset, args.targetdir, 'mfcc_hires' if args.hires else 'mfcc', '_vp_sp' if args.perturbed else '')
    if args.cmvn:
        check_call(['steps/compute_cmvn_stats.sh', args.targetdir])


def show(args):
    print("Cache")


def get(args):
    c = corpus_map[args.corpus.lower()]

    print("Dataset")


def _set_path():
    chdir(dirname(realpath(__file__)))
    sys.path = [join(dirname(realpath(__file__)), 'utils')] + sys.path
    os.environ['PATH'] = "{}:{}".format(join(dirname(realpath(__file__)), 'utils'), os.environ['PATH'])
    print(sys.path)
    print(os.environ['PATH'])


def main():
    _set_path()
    # create the top-level parser
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers()

    parser_status = subparsers.add_parser('status')
    parser_status.set_defaults(func=get_status)

    parser_cache = subparsers.add_parser('cache')
    parser_cache.add_argument('corpus')
    parser_cache.set_defaults(func=create_cache)

    parser_get = subparsers.add_parser('get')
    parser_get.add_argument('--perturbed', action='store_true')
    parser_get.add_argument('--hires', action='store_true')
    parser_get.add_argument('--cmvn', action='store_true')
    parser_get.add_argument('corpus')
    parser_get.add_argument('dataset')
    parser_get.add_argument('targetdir')
    parser_get.set_defaults(func=get)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
