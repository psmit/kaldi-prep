from __future__ import print_function
from lib.corpus import Corpus
from lib.selector import RegexSelector

import io

from os import walk
from os.path import join, splitext, exists


def read_info(fio_file):
    info = {p.split(": ")[0]: p.split(": ")[1].strip() for p in
            io.open(join(fio_file), encoding="iso-8859-1") if len(p.strip()) > 4}
    ort = info["LBO"].split(',')[3]
    prompt = info["LBR"].split(',')[5]
    sex = info["SEX"]
    age = info['AGE']
    accent = info["ACC"]

    if "#" in ort:
        ort1, ort2 = ort.split("#")
    else:
        ort1 = ort2 = ort

    return ort1, ort2, prompt, sex, age, accent


class SpeeconCorpus(Corpus,RegexSelector):
    def __init__(self):
        super(SpeeconCorpus, self).__init__()
        self.name = "speecon-fi"
        self.code = "SPC"
        self.lang = "FI"
        self.description = "Speecon corpus"

    def make_base_dir(self, paths, target_dir):
        devel_speakers = {'SA001','SA020','SA024','SA028','SA053','SA054','SA057','SA061','SA077','SA100','SA114','SA118','SA135','SA145','SA168','SA204','SA206','SA209','SA217','SA223','SA229','SA235','SA248','SA256','SA260','SA272','SA275','SA276','SA277','SA289','SA290','SA291','SA295','SA300','SA303','SA305','SA307','SA308','SA324','SA344','SA345','SA368','SA369','SA377','SA378','SA396','SA429','SA448','SA460','SA503',}
        eval_speakers = {'SA010','SA015','SA036','SA064','SA105','SA108','SA115','SA126','SA127','SA140','SA169','SA173','SA177','SA181','SA184','SA192','SA200','SA230','SA236','SA239','SA240','SA251','SA255','SA257','SA258','SA269','SA279','SA280','SA287','SA296','SA311','SA312','SA320','SA321','SA325','SA326','SA327','SA328','SA329','SA331','SA354','SA359','SA361','SA363','SA365','SA370','SA372','SA373','SA395','SA398','SA399','SA400','SA401','SA403','SA405','SA406','SA407','SA408','SA409','SA410','SA411','SA412','SA413','SA414','SA415','SA416','SA420','SA426','SA444','SA446','SA450','SA500','SA505','SA513','SA539',}
        speecon_dir = join(paths['TEAMWORK'], 'c', 'speecon-fi')

        FIO_files = {}
        for root, dirs, files in walk(speecon_dir):
            for f in files:
                if f.endswith(".FIO"):
                    FIO_files[f[:8]] = join(root, splitext(f)[0])
                if len(FIO_files) > 20:
                    break
            if len(FIO_files) > 20:
                break

        maps = {'wav.scp': 'wav',
                'text.ort1': 'ort1',
                'text.ort2': 'ort2',
                'text': 'text',
                'utt2prompt': 'prompt',
                'utt2spk': 'spk',
                'utt2type': 'type',
                'utt2sex': 'sex',
                'utt2accent': 'accent',
                'utt2uniq': 'speaker',
                'utt2set': 'dset'}

        fds = {k: io.open(join(target_dir, k), 'w', encoding='utf-8') for k,_ in maps.items()}

        for key, path in FIO_files.items():
            speaker = key[:5]
            type = key[5:]
            ort1, ort2, prompt, sex, age, accent = read_info(path + ".FIO")

            for chan in range(4):
                file_name = "{}.FI{}".format(path, chan)
                if not exists(file_name):
                    print("Missing: {}".format(file_name))
                    continue

                utt_key = "{}-{}-{}-ch{}-{}".format(self.lang, self.code, key[:5], chan, key[5:8])
                wav = "sox -b 16 -e signed-integer -r 16000 -t raw {} -r 16000 -t wav - |".format(file_name)

                text = ort1.replace("[sta]", " ").replace('_', '')
                if text.startswith('*'):
                    text = text[1:]
                text = " ".join(text.split())

                spk = "{}-ch{}".format(speaker, chan)

                dset = 'train'
                if spk in devel_speakers:
                    dset = 'devel'
                elif spk in eval_speakers:
                    dset = 'eval'

                for k,v in maps.items():
                    print(u"{} {}".format(utt_key, vars()[v]), file=fds[k])