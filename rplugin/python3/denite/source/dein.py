# ============================================================================
# FILE: dein.py
# AUTHOR: Shougo Matsushita <Shougo.Matsu at gmail.com>
# License: MIT license
# ============================================================================

from .base import Base
import re

class Source(Base):

    def __init__(self, vim):
        Base.__init__(self, vim)

        self.name = 'dein'
        self.kind = 'directory'

    def gather_candidates(self, context):
        pat = re.compile('^(https?|git)://(github.com/)?')
        return [{'word': pat.sub('', x['repo']),
                 'action__path': x['path']} for x
                in self.vim.eval('values(dein#get())')]
