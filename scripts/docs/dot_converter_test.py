# Copyright 2016 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Tests for DotConverter."""

import os
import sys
import unittest

from third_party.bazel.scripts.docs.dot_converter import DotConverter

CMD = ["dot", "-Tsvg"]
ENV = os.environ.copy()

class DotConverterTest(unittest.TestCase):
  """Unit tests for converting graphs."""

  def testDot(self):
    tmpin = "%s/stdin" % os.environ['TEST_TMPDIR']
    tmpout = "%s/stdout" % os.environ['TEST_TMPDIR']
    with open(tmpin, 'w') as writer:
      input_doc = """
This is some doc.

<div class="graphviz dot"><!--
digraph G1 {
  Target -> Rule;
  Rule -> lib;
}
--></div>

Some more doc.
"""
      writer.write(input_doc)

    sys.stdout = open(tmpout, 'w')
    cmd = CMD + [tmpin]
    converter = DotConverter(cmd, ENV)
    converter.convert()
    with open(tmpout, 'r') as reader:
      output = reader.read()
    print(output)
    self.assertNotEquals(output, input_doc)

if __name__ == '__main__':
    unittest.main()
