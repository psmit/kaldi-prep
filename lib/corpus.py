from __future__ import print_function
from os.path import join, exists, isdir
from os import listdir, makedirs, rename

from io import open

class Corpus(object):
    def __init__(self):
        self.lang = "NOTSET"
        self.name = "NOTSET"
        self.code = "NOTSET"
        self.description = "NOTSET"

        self._cached = None
        self._cache_dir = ''
        self._cache_version = 0

    def __str__(self):
        return "{}\t{}\t{}\t{}".format(self.lang, self.name, self.code, self.description)

    def _check_cache_status(self):
        self._cache_dir = join('cache', '{}-{}'.format(self.lang, self.code))
        if not exists(self._cache_dir):
            makedirs(self._cache_dir)
        if not isdir(self._cache_dir):
            raise Exception("This is bad, the cache dir ({}) isn't a directory".format(self._cache_dir))
        for d in listdir(self._cache_dir):
            if not isdir(join(self._cache_dir, d)):
                continue
            try:
                d = int(d)
                if d > self._cache_version:
                    self._cache_version = d
            except ValueError:
                pass

    def new_cache_dir(self):
        self._check_cache_status()
        self._cache_version += 1
        return join(self._cache_dir, str(self._cache_version))

    def make_base_dir(self, paths, target_dir):
        raise NotImplementedError

    def normalize(self, text):
        text = text.lower()

        words = text.split()
        output = []
        for word in words:
            if not word.startswith(u"#"):
                output.append(word.strip(u".,!:?"))
        return " ".join(output)

    def normalize_text_file(self, textfile):
        rename(textfile, "{}.unnormalized".format(textfile))
        with open(textfile, 'w', encoding='utf-8') as of:
            for line in open("{}.unnormalized".format(textfile), encoding='utf-8'):
                parts = line.strip().split(None, 1)
                k = parts[0]
                text = ""
                if len(parts) > 1:
                    text = self.normalize(parts[1])
                print(u"{} {}".format(k, text.strip()), file=of)


