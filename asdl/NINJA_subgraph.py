"""
asdl/NINJA_subgraph.py
"""

from __future__ import print_function

from build.ninja_lib import asdl_cpp, cc_binary, log

_ = log

def NinjaGraph(n):
  n.comment('Generated by %s' % __name__)
  n.newline()

  n.rule('asdl-cpp',
         command='_bin/shwrap/asdl_main $action $asdl_flags $in $out_prefix $debug_mod',
         description='asdl_main $action $asdl_flags $in $out_prefix $debug_mod')
  n.newline()

  # For pretty printing
  asdl_cpp(n, 'asdl/hnode.asdl', pretty_print_methods=False)

  # For unit tests
  asdl_cpp(n, 'asdl/examples/demo_lib.asdl')
  asdl_cpp(n, 'asdl/examples/typed_arith.asdl')
  asdl_cpp(n, 'asdl/examples/typed_demo.asdl')

  # TODO: can remove current dir
  if 0:
    cc_binary(n, 'asdl/gen_cpp_test.cc')
    cc_binary(n, 'asdl/gc_test.cc')
