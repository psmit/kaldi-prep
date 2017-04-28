from __future__ import print_function

from io import open
import collections
import locale
from os import makedirs, walk, sep, stat
from os.path import join, splitext, exists, normpath
from subprocess import check_output, check_call, STDOUT, CalledProcessError
import sys

from .spl import Spl

locale.setlocale(locale.LC_ALL, 'C')


def extract_corpus(spr_dir, files, targetdir):
    if not exists(targetdir):
        makedirs(targetdir)
    for md5, file in files:
        test_md5 = check_output(['md5sum', join(spr_dir, file)]).split()[0]
        assert md5 == test_md5

        check_call(['tar', 'xf', join(spr_dir, file), '--strip-components=3', '-C', targetdir])


def prep_corpus(prefix, source_dir, target_dir):
    err_counter = collections.Counter()

    wav_files = {}
    spl_files = {}

    for root, dirs, files in walk(normpath(source_dir)):
        parts = root.split(sep)

        for f in files:
            if f.endswith(".wav") and f.startswith("u"):
                key = parts[-2] + splitext(f)[0]
                wav_files[key.lower()] = join(root, f)

            if f.endswith(".spl"):
                key = parts[-1] + splitext(f)[0]
                spl_files[key.lower()] = join(root, f)

    fd_text = open(join(target_dir, 'text'), 'w', encoding='utf-8')
    fd_scp = open(join(target_dir, 'wav.scp'), 'w', encoding='utf-8')
    fd_utt2spk = open(join(target_dir, 'utt2spk'), 'w', encoding='utf-8')
    fd_utt2type = open(join(target_dir, 'utt2type'), 'w', encoding='utf-8')

    for key, val in spl_files.items():
        s = Spl(val)
        for valid, record in s.records():

            spl_wav_filename = splitext(valid[9])[0]
            wav_key = key[:8] + spl_wav_filename
            wav_key = wav_key.lower()

            utt_type = record[9]
            utt_text = " ".join(valid[0].split())
            if wav_key not in wav_files:
                err_counter["No such wavfile"] += 1
                continue

            file_name = wav_files[wav_key]

            if stat(file_name).st_size == 0:
                err_counter["File empty error"] += 1
                continue
            try:
                num_sam = int(check_output("soxi -s {}".format(file_name), stderr=STDOUT, shell=True))
            except CalledProcessError:
                err_counter["Reading file error"] += 1
                continue
            except ValueError:
                err_counter["Reading file error"] += 1
                continue

            if num_sam * 4 != int(valid[11]) - int(valid[10]):
                err_counter["Length incorrect error"] += 1
                continue

            for channel in ("1", "2"):
                utt_key = u"{}-{}-{}-ch{}-{}".format(prefix, key[:8], spl_wav_filename[1:5], channel, spl_wav_filename[5:])

                print(u"{} sph2pipe -f wav -p -c {} {} |".format(utt_key, channel, file_name), file=fd_scp)
                print(u"{} {}".format(utt_key, utt_text), file=fd_text)
                print(u"{} {}".format(utt_key, utt_key[:21]), file=fd_utt2spk)
                print(u"{} {}".format(utt_key, utt_type), file=fd_utt2type)

    for type, count in err_counter.most_common():
        print("{} errors of type \"{}\" occured".format(count, type), file=sys.stderr)
