from __future__ import print_function
from __future__ import absolute_import


from .spraakbanken import extract_corpus, prep_corpus
from lib.corpus import Corpus
from lib.selector import RegexSelector

from os.path import join


class SwedishSpraakbankenCorpus(Corpus, RegexSelector):
    def __init__(self):
        super(SwedishSpraakbankenCorpus, self).__init__()
        self.name = "spraakbanken-sv"
        self.code = "SPR"
        self.lang = "SV"
        self.description = "Spraakbanken Swedish corpus"

    def make_base_dir(self, paths, target_dir):
        spr_dir = join(paths['TEAMWORK'], 'c', 'spraakbanken', 'all')

        files = [('9ef845e486136b5b13502dfdba6c9d25', 'sve.16khz.0468.tar.gz'),
                 ('90c5c106fa3f869599533201d73fe332', 'sve.16khz.0467-1.tar.gz'),
                 ('4d8efa0a71dca669754a3b6554f8e4b3', 'sve.16khz.0467-2.tar.gz'),
                 ('bef9c30ae7de4c77264dccfad349b7f3', 'sve.16khz.0467-3.tar.gz'),
                 ('eaea63597c241118dad9ab625e5f471e', 'sve.nolelyder.tar.gz'),
                 ]

        tmpdir = join(target_dir, 'tmptar')
        extract_corpus(spr_dir, files, tmpdir)

        prep_corpus("{}-{}".format(self.lang, self.code), tmpdir, target_dir)