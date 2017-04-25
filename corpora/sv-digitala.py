from __future__ import print_function

from itertools import chain
from os.path import join, splitext, isfile
from os import walk, listdir

from lib.corpus import Corpus
from lib.selector import RegexSelector

from io import open


def unify_keys(keymap):
    n = {}
    for k,v in keymap.items():
        location, rest = k.split('_', 1)
        k = "{}-{}".format(location[:5], rest.replace('_', '-'))
        n[k] = v
    return n


class DigitalaCorpus(Corpus, RegexSelector):
    def __init__(self):
        super(DigitalaCorpus, self).__init__()
        self.name = "digitala1"
        self.code = "DG1"
        self.lang = "SV"
        self.description = "Digitala corpus"

    def make_base_dir(self, paths, target_dir):
        dgt_dir = join(paths['TEAMWORK'], 'c', 'digitala')

        wav_files = {}
        for root, dirs, files in chain(walk(join(dgt_dir, 'pilot_test_corpus', 'raw')),
                                       walk(join(dgt_dir, 'first_round'))):
            if 'test' in dirs:
                dirs.remove('test')

            for file in files:
                if file.endswith('.wav'):
                    wav_files[splitext(file)[0]] = join(root, file)

        transcriptions1001 = {}

        for file in listdir(join(dgt_dir, 'annotation_teemu011016')):
            if not isfile(join(dgt_dir, 'annotation_teemu011016', file)):
                continue
            transcriptions1001[splitext(file)[0]] = "  ".join(l.strip() for l in open(join(dgt_dir, 'annotation_teemu011016', file), encoding='utf-8'))

        transcriptions2609 = {}
        prompt2609 = {}
        for file in listdir(join(dgt_dir, 'annotation_teemu260916')):
            if not isfile(join(dgt_dir, 'annotation_teemu260916', file)):
                continue
            cur_utt = None
            cur_text = []

            for line in open(join(dgt_dir, 'annotation_teemu260916', file), encoding='utf-8'):
                if len(line.strip()) > 1 and '_' in line.split()[0]:
                    if cur_utt is not None:
                        transcriptions2609[cur_utt] = '  '.join(cur_text).strip()
                    parts = line.strip().split(None, 1)
                    cur_utt = parts[0]
                    prompt2609[cur_utt] = parts[1]
                    cur_text = []
                else:
                    cur_text.append(line.strip())

            if cur_utt is not None:
                transcriptions2609[cur_utt] = '  '.join(cur_text).strip()

        transcriptions_first_round = {}
        d = join(dgt_dir, 'transcriptions', 'align', 'first_round')
        for file in listdir(d):
            if isfile(join(d,file)) and file.endswith('trn'):
                transcriptions_first_round[splitext(file)[0]] = " ".join(l.strip() for l in open(join(d,file), encoding='iso-8859-15').readlines())


        transcriptions_read = {}
        d = join(dgt_dir, 'pilot_test_corpus','prompts','read_sentences')
        for root, dirs, files in walk(d):
            for file in files:
                if file.endswith('txt'):
                    transcriptions_read[splitext(file)[0]] = " ".join(l.strip() for l in open(join(root,file), encoding='utf-8').readlines())


        wav_files = unify_keys(wav_files)
        transcriptions2609 = unify_keys(transcriptions2609)
        transcriptions1001 = unify_keys(transcriptions1001)
        transcriptions_first_round = unify_keys(transcriptions_first_round)
        transcriptions_read = unify_keys(transcriptions_read)

        transcriptions = {}
        transcriptions.update(transcriptions1001)
        transcriptions.update(transcriptions2609)
        transcriptions.update(transcriptions_first_round)
        transcriptions.update(transcriptions_read)

        present_trans = {}
        for k in transcriptions.keys():
            if k in wav_files:
                present_trans[k] = transcriptions[k]

        #print("{} transcriptions, {} after filtering".format(len(transcriptions), len(present_trans)))

        sets = {}
        for k in present_trans.keys():
            if k in transcriptions_read:
                sets[k] = 'train-read'
            elif k in transcriptions_first_round:
                sets[k] = 'eval-read'
            elif k in transcriptions2609 or k in transcriptions1001:
                sets[k] = 'spont'
            else:
                raise NotImplementedError

        wavscp = open(join(target_dir, 'wav.scp'), 'w', encoding='utf-8')
        utt2spk = open(join(target_dir, 'utt2spk'), 'w', encoding='utf-8')
        text = open(join(target_dir, 'text'), 'w', encoding='utf-8')
        utt2set = open(join(target_dir, 'utt2set'), 'w', encoding='utf-8')

        for k in present_trans.keys():
            print(u"{}-{}-{} {}".format(self.lang, self.code, k, present_trans[k]), file=text)
            print(u"{}-{}-{} sox {} -r 16k -t wav - remix - |".format(self.lang, self.code, k, wav_files[k]), file=wavscp)
            print(u"{}-{}-{} {}".format(self.lang, self.code, k, sets[k]), file=utt2set)
            print(u"{}-{}-{} {}".format(self.lang, self.code, k, '-'.join(k.split('-')[:2])), file=utt2spk)



