# coding=utf-8
from __future__ import print_function
import locale

from lib.corpus import Corpus
from lib.selector import AllSelector

from codecs import decode
import io

from os import walk, listdir
from os.path import join, splitext, exists

from subprocess import check_output

locale.setlocale(locale.LC_ALL, 'C')

def asciify(s):
    return s.replace(u"Ö", u"Oe").replace(u"Ä", u"Ae").replace(u"Å", u"Aa").replace(u"ö", u"oe").replace(u"ä", u"ae")


class TalkoCorpus(Corpus,AllSelector):
    def __init__(self):
        super(TalkoCorpus, self).__init__()
        self.name = "talko"
        self.code = "TAL"
        self.lang = "SV"
        self.description = "Talko corpus"

    def make_base_dir(self, paths, target_dir):
        talko_dir = join(paths['TEAMWORK'], 'c', 'talko')

        wav_files = {}
        for f in listdir(join(talko_dir, 'wav')):
            if f.endswith('.wav'):
                wav_files[splitext(f)[0]] = join(talko_dir, 'wav', f)

        wav = {}
        speaker = {}
        time = {}
        ort = {}
        trans = {}

        sn = 0
        for f in sorted(listdir(join(talko_dir, 'trs')), key=str.lower):
            sn += 1
            if f.endswith('.trs'):
                text = decode(check_output(['external/parsetrs.v0.74.pl', join(talko_dir, 'trs', f)]), 'iso-8859-15')
                n = 0
                for line in text.splitlines():
                    if line.startswith(';;'):
                        continue
                    parts = line.split(None, 6)
                    if not parts[2].startswith(parts[0]):
                        continue
                    spk = asciify(parts[2][len(parts[0])+1:])

                    n += 1

                    utt = u"{}-{}-{}-{:03}-{:04d}".format(self.lang, self.code, spk, sn, n)
                    print(utt)
                    wav[utt] = parts[0]
                    speaker[utt] = u"{}-{}-{}".format(self.lang, self.code, spk)
                    time[utt] = (float(parts[3]), float(parts[4]))
                    trans[utt] = parts[6]

        sn = 0
        for f in sorted(listdir(join(talko_dir, 'overs')), key=str.lower):
            sn += 1
            if f.endswith('.trs'):
                text = decode(check_output(['external/parsetrs.v0.74.pl', join(talko_dir, 'overs', f)]), 'iso-8859-15')
                n = 0
                for line in text.splitlines():
                    if line.startswith(';;'):
                        continue
                    parts = line.split(None, 6)
                    if not parts[2].startswith(parts[0]):
                        continue
                    spk = asciify(parts[2][len(parts[0])+1:])

                    n += 1

                    utt = u"{}-{}-{}-{:03}-{:04d}".format(self.lang, self.code, spk, sn, n)
                    print(utt)
                    ort[utt] = parts[6]

        with io.open(join(target_dir, 'wav.scp'), 'w', encoding='utf-8') as of:
            for k in sorted(wav_files.keys(), key=locale.strxfrm):
                print(u"{} sox {} -r 16k -t wav - remix - |".format(k, wav_files[k]), file=of)

        with io.open(join(target_dir, 'segments'), 'w', encoding='utf-8') as of:
            for k in sorted(wav.keys(), key=locale.strxfrm):
                print(u"{} {} {} {}".format(k, wav[k], time[k][0], time[k][1]), file=of)

        for file,v in ('utt2trans', 'trans'), ('text','ort'), ('utt2spk', 'speaker'):
            with io.open(join(target_dir, file), 'w', encoding='utf-8') as of:
                for k in sorted(wav.keys(), key=locale.strxfrm):
                    print(u"{} {}".format(k, vars()[v][k]), file=of)

