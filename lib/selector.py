from __future__ import print_function

from io import open
import re
from os import listdir, lstat, chmod

from os.path import join, exists

from shutil import copy
from subprocess import check_call, check_output, Popen, PIPE

import operator

from lib import NotYetCachedError
from stat import S_IWGRP, S_IWUSR, S_IMODE


class Selector(object):
    def list_datasets(self):
        raise NotImplementedError

    def get_dataset(self, dataset, target_dir, conf='mfcc', suffix=''):
        raise NotImplementedError

    @staticmethod
    def _copy_with_keylist(source_dir, target_dir, keys, conf):
        check_call(['utils/copy_data_dir.sh',
                    source_dir, target_dir])

        copy(join(source_dir, 'utt2numframes.{}'.format(conf)), join(target_dir, 'utt2num_frames'))
        feat_file = join(source_dir, '{}.scp'.format(conf))

        with open(join(target_dir, 'feats.scp'), 'w', encoding='utf-8') as of:
            for line in open(feat_file, encoding='utf-8'):
                k = line.split()[0]
                if k in keys or k.startswith('sp') and '-' in k and k[k.index('-')] in keys:
                    print(line.strip(), file=of)

        if exists(join(source_dir, 'stm.byid')):
            utt_to_wav_map = {}
            for line in open(join(source_dir, 'segments'), encoding='utf-8'):
                parts = line.split()
                utt_to_wav_map[parts[0]] = parts[1]
            with open(join(target_dir, 'stm'), 'w', encoding='utf-8') as of:
                for line in open(join(source_dir, 'stm.byid'), encoding='utf-8'):
                    parts = line.split()
                    if parts[0] not in keys:
                        continue
                    parts[0] = utt_to_wav_map[parts[0]]
                    print(" ".join(parts), file=of)
        min_perm = S_IWUSR | S_IWGRP
        for f in listdir(target_dir):
            chmod(join(target_dir, f), S_IMODE(lstat(join(target_dir, f)).st_mode) | min_perm)
        check_call(['utils/fix_data_dir.sh', target_dir])

class AllSelector(Selector):

    def _find_keys(self, source_dir):
        return {line.split()[0] for line in open(join(source_dir, 'utt2spk'), encoding='utf-8')}

    def list_datasets(self):
        return ['all']

    def get_dataset(self, dataset, target_dir, conf='mfcc', suffix=''):
        self._check_cache_status()
        if self._cache_version == 0:
            raise NotYetCachedError

        all_dir = join(self._cache_dir, str(self._cache_version), 'all')
        source_dir = join(self._cache_dir, str(self._cache_version), 'all{}'.format(suffix))
        keys = self._find_keys(all_dir)
        self._copy_with_keylist(source_dir, target_dir, keys, conf)



class RegexSelector(Selector):

    def _filter(self, specs, indir):
        keys = {line.split()[0] for line in open(join(indir, 'utt2spk'), encoding='utf8')}

        specs = open(specs, encoding='utf-8')
        key_r = re.compile(specs.readline().strip())
        val_rd = {p.split(None, 1)[0]: re.compile(p.strip().split(None, 1)[1]) for p in specs.readlines()}

        keys = {k for k in keys if key_r.match(k) is not None}
        for filename, regex in val_rd.items():
            new_keys = set()
            for line in open(join(indir, filename), encoding='utf-8'):
                k,v = line.strip().split(None,1)
                if k in keys and regex.match(v) is not None:
                    new_keys.add(k)
            keys = new_keys

        return keys

    def list_datasets(self):
        return list(listdir(join('dataset_definitions', '{}-{}'.format(self.lang, self.code).lower())))

    def get_dataset(self, dataset, target_dir, conf='mfcc', suffix=''):
        self._check_cache_status()
        if self._cache_version == 0:
            raise NotYetCachedError

        definition = join('dataset_definitions', '{}-{}'.format(self.lang, self.code).lower(), dataset)
        all_dir = join(self._cache_dir, str(self._cache_version), 'all')
        source_dir = join(self._cache_dir, str(self._cache_version), 'all{}'.format(suffix))

        keys = self._filter(definition, all_dir)

        self._copy_with_keylist(source_dir, target_dir, keys, conf)


class AdvancedRegexSelector(RegexSelector):
    def _filter(self, specs, indir):
        keys = {line.split()[0] for line in open(join(indir, 'utt2spk'), encoding='utf8')}

        specs = open(specs, encoding='utf-8')
        key_r = re.compile(specs.readline().strip())
        val_rd = {}
        comp_funcs = {}

        ops = {
            '<': operator.lt,
            '>': operator.gt,
            '<=': operator.le,
            '>=': operator.ge,
            '==': operator.eq,
        }
        for line in specs.readlines():
            parts = line.strip().split()
            if len(parts) == 3 and parts[1] in ops.keys():
                comp_val = float(parts[2])
                comp_funcs[parts[0]] = lambda x : ops[parts[1]](x,comp_val)
            else:
                val_rd[parts[0]] = re.compile(" ".join(parts[1:]))
        #val_rd = {p.split(None, 1)[0]: re.compile(p.strip().split(None, 1)[1]) for p in specs.readlines()}

        keys = {k for k in keys if key_r.match(k) is not None}
        for filename, regex in val_rd.items():
            new_keys = set()
            for line in open(filename, encoding='utf-8'):
                k, v = line.strip().split(None, 1)
                if k in keys and regex.match(v) is not None:
                    new_keys.add(k)
            keys = new_keys

        for filename, f in comp_funcs.items():
            new_keys = set()
            for line in open(filename, encoding='utf-8'):
                k, v = line.strip().split(None, 1)
                if k in keys and f(v):
                    new_keys.add(k)
            keys = new_keys

        return keys







