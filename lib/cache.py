from __future__ import print_function
import locale
from itertools import chain

locale.setlocale(locale.LC_ALL, 'C')

import io

from os import makedirs, listdir, walk, chmod, lstat
from os.path import join, exists, isdir

from shutil import rmtree, copytree, copy
from subprocess import check_call

from stat import S_IWGRP,S_IWUSR,S_IWOTH, S_IMODE


def _remove_write_permissions(path):
    remove_write = ~S_IWUSR & ~S_IWOTH &  ~S_IWGRP
    for root, dirs, files in walk(path, False):
        for p in chain(dirs, files):
            chmod(join(root,p), S_IMODE(lstat(join(root,p)).st_mode) & remove_write)


def make_cache(source, target):
    makedirs(join(target, 'data'))
    makedirs(join(target, 'all'))

    for f in listdir(source):
        if f == 'wav.scp' or isdir(join(source,f)):
            continue

        print(f)
        m = {}
        for line in io.open(join(source, f), encoding='utf-8'):
            parts = line.strip().split(None, 1)
            k = parts[0]
            v = "" if len(parts) < 2 else parts[1]
            m[k] = v
        with io.open(join(target, 'all', f), 'w', encoding='utf-8') as of:
            for k in sorted(m.keys(), key=locale.strxfrm):
                print(u"{} {}".format(k, m[k]), file=of)

    check_call(['sort', '-o', join(source, 'wav.scp'), join(source, 'wav.scp')])
    try:
        check_call(['lfs', 'setstripe', '-c', '6', join(target, 'data')])
    except OSError:
        pass
    check_call(['wav-copy',
                'scp:{}'.format(join(source, 'wav.scp')),
                'ark,scp:{},{}'.format(join(target, 'data', 'all_wav.ark'),
                                       join(target, 'all', 'wav.scp'))])

    check_call(['utils/data/get_utt2dur.sh',
                join(target, 'all')])
    check_call(['utils/fix_data_dir.sh',
                join(target, 'all')])

    copytree(join(target, 'all'),
             join(target, 'all_vp'))

    check_call(['utils/data/perturb_data_dir_volume.sh',
                join(target, 'all_vp')])
    check_call(['utils/fix_data_dir.sh',
                join(target, 'all_vp')])

    check_call(['utils/data/perturb_data_dir_speed_3way.sh',
                join(target, 'all_vp'),
                join(target, 'all_vp_sp')])
    check_call(['utils/fix_data_dir.sh',
                join(target, 'all_vp_sp')])

    nj = 1 + int(sum(float(line.split(None,1)[1])
                     for line in io.open(join(target, 'all', 'utt2dur'), encoding='utf-8'))
                 ) // 1000

    print("{} jobs".format(nj))

    for ddir in ('all', 'all_vp_sp'): # , 'all_vp'
        for conf in ('mfcc', 'mfcc_hires'):
            tmpdir=join(target, 'tmp', '{}-{}'.format(ddir, conf))
            makedirs(tmpdir)
            for f in ('wav.scp', 'segments', 'utt2spk', 'spk2utt'):
                if exists(join(target, ddir, f)):
                    copy(join(target, ddir, f), tmpdir)
            check_call(['steps/make_mfcc.sh',
                        '--mfcc-config', 'conf/{}.conf'.format(conf),
                        '--nj', str(nj),
                        '--cmd', 'slurm.pl --mem 2G',
                        tmpdir])

            check_call(['copy-feats',
                        '--write-num-frames=ark,t:{target}/{ddir}/utt2numframes.{conf}'.format(**locals()),
                        '--compress=true',
                        'scp:{}/feats.scp'.format(tmpdir),
                        'ark,scp:{target}/data/{ddir}_{conf}.ark,{target}/{ddir}/{conf}.scp'.format(**locals())])
            rmtree(tmpdir)

    _remove_write_permissions(target)
