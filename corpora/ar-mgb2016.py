from __future__ import print_function

from os import listdir
from os.path import join, splitext
from re import match

from subprocess import check_output
from xml.sax.saxutils import unescape

from .mgb import loadXml
from lib.corpus import Corpus
from lib.selector import AdvancedRegexSelector

from io import open



class ArabicMgb2016Corpus(Corpus, AdvancedRegexSelector):
    def __init__(self):
        super(ArabicMgb2016Corpus, self).__init__()
        self.name = "mgb2-arabic"
        self.code = "MG2"
        self.lang = "AR"
        self.description = "Arabic MGB-2 corpus"


    def make_base_dir(self, paths, target_dir):
        in_dir = join(paths['TEAMWORK'], 'c', 'talko', 'mgb','2017','arabic','data')

        maps = {'segments': 'segment',
                'text': 'words',
                'utt2spk': 'speaker_id',
                'utt2set': 'd',
                'utt2wmer': 'wmer',
                'utt2pmer': 'pmer',
                'utt2awd': 'awd',
                'utt2sel': 'sel',
                }

        fds = {k: open(join(target_dir, k), 'w', encoding='utf-8') for k, _ in maps.items()}
        stm = open(join(target_dir, 'stm.byid'), 'w', encoding='utf-8')
        wav_map = {}
        utt_map = {}

        sel_map = {}
        for f in ('music', 'silence', 'overlap_speech', 'non_overlap_speech'):
            for line in open(join('corpora', 'mgb', '2016', "{}.lst".format(f)), encoding='utf-8'):
                if len(line.strip()) > 0:
                    sel_map[line.strip()] = f


        for d in ("train", "dev"):
            for x in listdir(join(in_dir, 'xml', d)):
                xml = join(in_dir, 'xml', d, x)
                wav_file = join(in_dir,'wav', d, "{}.wav".format(splitext(x)[0]))
                basename = splitext(x)[0]
                wav_name = "{}-{}-{}".format(self.lang, self.code, basename)
                wav_map[wav_name] = wav_file

                for line in check_output(['xmlstarlet',
                                          'sel', '-t', '-m',
                                          '//segments',
                                          '-m', "segment", '-n', '-v',
                                          "concat(@who,' ',@starttime,' ',@endtime,' ',@AWD,' ',@WMER,' ',@PMER,' ')",
                                          '-m', "element", '-v', "concat(text(),' ')", xml]).splitlines():
                    m = match(r'\w+speaker(\d+)\w+\s+(.*)', line)
                    if m:
                        spk = int(m.group(1))

                        t = m.group(2).split()
                        start = float(t[0])
                        end = float(t[1])
                        awd = float(t[2])
                        pmer = float(t[3])
                        wmer = float(t[4])

                        s = [unescape(w) for w in t[5:]]
                        words = ' '.join(s)

                        utterance_id = "{}-{}-{}-{:04d}_seg-{:07d}-{:07d}".format(self.lang, self.code, basename, spk, start*100, end*100)
                        utt_map[(basename, "{:07d}".format(start*100),"{:07d}".format(end*100))] = utterance_id
                        speaker_id = "{}-{}-{}-{:04d}".format(self.lang, self.code, basename, spk)
                        segment = "{} {} {}".format(wav_name, start, end)
                        sel = sel_map.get("{}_spk-{:04d}_seg-{:07d}:{:07d}".format(basename, spk, start*100, end*100), 'other')


                        for k, v in maps.items():
                            print(u"{} {}".format(utterance_id, vars()[v]), file=fds[k])


                data = loadXml(xml)
                for e in data['turn']:
                    print("{} 0 UNKNOWN {:.02f} {:.02f} {}".format(utt_map[(data['id'], "{:07d}".format(e.startTime*100), "{:07d}".format(e.endTime*100))], e.startTime, e.endTime, e.text), file=stm)

        stm.close()
        with open(join(target_dir, 'wav.scp'), 'w', encoding='utf-8') as wav_file:
            for k, v in wav_map.items():
                print("{} {}".format(k,v), file=wav_file)
