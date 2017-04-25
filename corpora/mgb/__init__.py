from __future__ import print_function
from xml.dom.minidom import parse

_unicode = u"\u0622\u0624\u0626\u0628\u062a\u062c\u06af\u062e\u0630\u0632\u0634\u0636\u0638\u063a\u0640\u0642\u0644\u0646\u0648\u064a\u064c\u064e\u0650\u0652\u0670\u067e\u0686\u0621\u0623\u0625\u06a4\u0627\u0629\u062b\u062d\u062f\u0631\u0633\u0635\u0637\u0639\u0641\u0643\u0645\u0647\u0649\u064b\u064d\u064f\u0651\u0671"
_buckwalter = u"|&}btjGx*z$DZg_qlnwyNaio`PJ'><VApvHdrsSTEfkmhYFKu~{"

_forwardMap = {ord(a):b for a,b in zip(_unicode, _buckwalter)}
_backwardMap = {ord(b):a for a,b in zip(_unicode, _buckwalter)}


def toBuckWalter(s):
  return s.translate(_forwardMap)


def fromBuckWalter(s):
  return s.translate(_backwardMap)


class Element(object):
  def __init__(self, text, startTime, endTime=None):
    self.text = text
    self.startTime = startTime
    self.endTime = endTime


def loadXml(xmlFileName):
    dom = parse(open(xmlFileName, 'r'))
    trans = dom.getElementsByTagName('transcript')[0]
    segments = trans.getElementsByTagName('segments')[0]
    elements = []
    for segment in segments.getElementsByTagName('segment'):
        sid = segment.attributes['id'].value.split('_utt_')[0].replace("_","-")
        startTime = float(segment.attributes['starttime'].value)
        endTime = float(segment.attributes['endtime'].value)

        tokens = [e.childNodes[0].data for e in segment.getElementsByTagName('element') if len(e.childNodes)]
        # skip any word starts with '#'
        tokens = filter(lambda i: not i.startswith('#'), tokens)
        text = ' '.join(tokens)

        elements.append(Element(text, startTime, endTime))
    return {'id': sid, 'turn': elements}
