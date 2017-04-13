from __future__ import print_function

import io
import re
from os import listdir

from os.path import join

from shutil import copy
from subprocess import check_call

from lib import NotYetCachedError


class Selector(object):
    def list_datasets(self):
        raise NotImplementedError

    def get_dataset(self, dataset, target_dir, conf='mfcc', suffix=''):
        raise NotImplementedError


class RegexSelector(object):
    def __init__(self):
        print("RegexSelector init")

    def _filter(self, specs, indir):
        keys = {line.split()[0] for line in io.open(join(indir, 'utt2spk'), encoding='utf8')}

        specs = io.open(specs, encoding='utf-8')
        key_r = re.compile(specs.readline().strip())
        val_rd = {p.split(None, 1)[0]: re.compile(p.strip().split(None, 1)[1]) for p in specs.readlines()}

        keys = {k for k in keys if key_r.match(k) is not None}
        for filename, regex in val_rd.items():
            new_keys = set()
            for line in io.open(filename, encoding='utf-8'):
                k,v = line.strip().split(None,1)
                if k in keys and regex.match(v) is not None:
                    new_keys.add(k)
            keys = new_keys

    def list_datasets(self):
        return list(listdir(join('dataset_definitions', '{}-{}'.format(self.lang, self.code).lower())))

    def get_dataset(self, dataset, target_dir, conf='mfcc', suffix=''):
        self._check_cache_status()
        if self._cache_version == 0:
            raise NotYetCachedError

        definition = join('dataset_definitions', '{}-{}'.format(self.lang, self.code).lower(), dataset)
        source_dir = join(self._cache_dir, str(self._cache_version), 'all{}'.format(suffix))

        check_call(['utils/copy_data_dir.sh',
                    source_dir, target_dir])

        copy(join(source_dir, 'utt2numframes.{}'.format(conf)), join(target_dir, 'utt2num_frames'))
        feat_file = join(source_dir, '{}.scp'.format(conf))
        keys = self._filter(definition, source_dir)

        with io.open(join(target_dir, 'feats.scp'), 'w', encoding='utf-8') as of:
            for line in io.open(feat_file, encoding='utf-8'):
                k = line.split()[0]
                if k in keys:
                    print(line.strip(), file=of)

        check_call(['utils/fix_data_dir.sh', target_dir])







